# iol_client.rb
require 'httparty'
require 'time'
require 'json'
require 'uri'

class IOLClient
  include HTTParty
  base_uri "https://api.invertironline.com"

  class Error < StandardError; end
  class AuthError < Error; end
  class NetworkError < Error; end

  # Constants from your modules
  ALLOWED_MARKETS = %w[BCBA NYSE NASDAQ AMEX BCS ROFX].freeze
  ALLOWED_COUNTRIES = %w[Argentina Estados_Unidos].freeze
  SETTLEMENTS = %w[T1 CI].freeze

  CACHE_FILE = "iol_clients_cache.json"
  
  def initialize
    @username = ENV['IOL_USERNAME']
    @password = ENV['IOL_PASSWORD']
    
    if @username.nil? || @password.nil?
      raise Error, "Missing Credentials! Please set IOL_USERNAME and IOL_PASSWORD env vars."
    end
    
    @token = nil
    @token_expires_at = nil
  end

  # -- Auth --
  def token
    return @token if @token && !token_expired?
    login!
  end

  def login!
    response = self.class.post("/token",
      body: { 
        grant_type: "password", 
        username: @username, 
        password: @password 
      }
    )

    if response.success?
      data = response.parsed_response
      @token = data["access_token"]
      @refresh_token = data["refresh_token"]
      # Use standard Time.now
      @token_expires_at = Time.now + data["expires_in"].to_i
      @token
    else
      raise AuthError, "Login failed: #{response.body}"
    end
  end

  # -- Helpers --
  def get(path, query: {})
    ensure_auth!
    response = self.class.get(path, headers: auth_header, query: query)
    handle_response(response)
  end

  def post(path, body: {})
    ensure_auth!
    response = self.class.post(path, headers: auth_header, body: body)
    handle_response(response)
  end

  # ---------------------------------------------------------
  # ASESOR ENDPOINTS (Restored)
  # ---------------------------------------------------------

  # GET /api/v2/Asesores/Clientes
  def get_all_clients
    clients = fetch_raw_clients_from_api
    refresh_client_cache!(clients)
    clients
  end

  # 2. Smart Resolver: Returns ID from cache (checks full object)
  def get_client_id_by_account(account_number, force_refresh: false)
    client = get_client_by_account(account_number, force_refresh: force_refresh)
    client["id"]
  end

  # 3. Get Full Client Object (from cache)
  def get_client_by_account(account_number, force_refresh: false)
    load_cache
    acc_str = account_number.to_s
    
    # Return immediately if found and not forced
    return @client_map[acc_str] if @client_map[acc_str] && !force_refresh

    # Otherwise, fetch fresh list
    refresh_client_cache!
    
    # Try again
    client = @client_map[acc_str]
    raise Error, "Client with account #{account_number} not found." unless client
    client
  end

  # 4. Search clients by string (Name, Surname, or Account)
  def find_clients(query)
    load_cache
    q = query.to_s.downcase
    @client_map.values.select do |c|
      c["nombre"].to_s.downcase.include?(q) || 
      c["apellido"].to_s.downcase.include?(q) || 
      c["numeroCuenta"].to_s.include?(q)
    end
  end

  # 5. Calculate Total AUM from cache
  def calculate_aum
    load_cache
    @client_map.values.sum { |c| c["totalCuentaValorizado"].to_f }
  end

  # 6. Cache Refresher: Stores FULL object keyed by Account Number
  def refresh_client_cache!(data = nil)
    raw_clients = data || fetch_raw_clients_from_api
    
    new_map = {}
    raw_clients.each do |c|
      acc_num = c["numeroCuenta"]
      if acc_num
        new_map[acc_num.to_s] = c
      end
    end

    @client_map = new_map
    save_cache
    new_map
  end

  # GET /api/v2/Asesores/EstadoDeCuenta/{id}
  def get_client_account(client_id)
    get("/api/v2/Asesores/EstadoDeCuenta/#{client_id}")
  end

  # GET /api/v2/Asesores/Portafolio/{id}/{pais}
  def get_client_portfolio(client_id, country: "Argentina")
    country = validate!(country, ALLOWED_COUNTRIES, "Country")
    get("/api/v2/Asesores/Portafolio/#{client_id}/#{country}")
  end

  # GET /api/v2/Asesores/Operaciones (Securities Transactions)
  def get_client_transactions(client_id:, from_date:, to_date:, status: "Pendientes", country: "Argentina")
    raise ArgumentError, "Invalid country" unless ALLOWED_COUNTRIES.include?(country)
    
    query = {
      IdClienteAsesorado: client_id,
      Estado:             status,
      Pais:               country,
      FechaDesde:         iso_date(from_date),
      FechaHasta:         iso_date(to_date)
    } # Removed .compact as it is not needed if we ensure values exist

    # Use query params here, not body
    get("/api/v2/Asesores/Operaciones", query: query)
  end

  # POST /api/v2/Asesor/Movimiento/Historico/{id} (Bank Transfers/Deposits)
  def get_client_transfers(client_id, from_date:, to_date:, id_tipo: nil, id_estado: nil)
    body = {
      Desde: iso_date(from_date),
      Hasta: iso_date(to_date),
      IdTipo:     id_tipo,
      IdEstado:   id_estado
    }.select { |_, v| !v.nil? } # Ruby standard .compact replacement for hash values

    post("/api/v2/Asesor/Movimiento/Historico/#{client_id}", body: body)
  end

  # -- Market Data (Titulos) --
  def get_quote(symbol, market: "BCBA", settlement: "T1")
    market = validate!(market, ALLOWED_MARKETS, "Market")
    settlement = validate!(settlement, SETTLEMENTS, "Settlement")
    get("/api/v2/#{market}/Titulos/#{symbol}/Cotizacion", query: { plazo: settlement })
  end

  def get_financials(symbol, market: "BCBA")
    market = validate!(market, ALLOWED_MARKETS, "Market")
    get("/api/v2/#{market}/Titulos/#{symbol}/CotizacionDetalle")
  end

  def get_options(symbol, market: "BCBA")
    market = validate!(market, ALLOWED_MARKETS, "Market")
    get("/api/v2/#{market}/Titulos/#{symbol}/Opciones")
  end

  # -- Account (Asesor/User) --
  def get_account_state
    # Usually works for the logged in user
    get("/api/v2/datos-perfil") 
  end

  def get_portfolio(country: "Argentina")
    country = validate!(country, ALLOWED_COUNTRIES, "Country")
    get("/api/v2/Estadisticas/InformeDiario/#{country}") 
    # Note: IOL API endpoints change often between 'Asesor' and standard user. 
    # If this fails, we might need the specific endpoint for the self-managed account.
  end
  
  def get_operations(from_date, to_date, status: "Terminadas", country: "Argentina")
     # Simplified for CLI use
     get("/api/v2/Operaciones", query: {
       estado: status,
       fechaDesde: from_date,
       fechaHasta: to_date,
       pais: country
     })
  end

  private

  def fetch_raw_clients_from_api
    get("/api/v2/Asesores/Clientes")
  end

  def load_cache
    return if @client_map # Already loaded in memory
    
    if File.exist?(CACHE_FILE)
      begin
        @client_map = JSON.parse(File.read(CACHE_FILE))
      rescue JSON::ParserError
        @client_map = {}
      end
    else
      @client_map = {}
    end
  end

  def save_cache
    File.write(CACHE_FILE, JSON.pretty_generate(@client_map))
  end

  def ensure_auth!
    login! if token_expired? || @token.nil?
  end

  def token_expired?
    @token_expires_at && Time.now >= @token_expires_at
  end

  def auth_header
    { "Authorization" => "Bearer #{@token}" }
  end

  def handle_response(response)
    if response.success?
      response.parsed_response
    else
      raise NetworkError, "API Error #{response.code}: #{response.body}"
    end
  end

  def validate!(value, list, name)
    val = value.to_s.upcase
    unless list.include?(val) || (list.include?(value.to_s)) # Check both case insensitive and exact
      # specific fix for 'Argentina' being TitleCase in constants but sometimes sent differently
      return value if list.map(&:downcase).include?(value.to_s.downcase)
    end
    val
  end
end