#!/usr/bin/env ruby
require_relative 'iol_client'
require 'optparse'
require 'json'
require 'date'
require 'time'

# --- Formatting Helpers ---
module Formatter
  def self.currency(amount, decimals: 2)
    return "0.00" if amount.nil? || amount == 0
    parts = sprintf("%.#{decimals}f", amount).split('.')
    int_part = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    dec_part = parts[1]
    "#{int_part}.#{dec_part}"
  end

  def self.number(amount)
    return "0" if amount.nil? || amount == 0
    amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def self.colorize(text, val)
    return text if val.nil?
    color = val > 0 ? "\e[32m" : (val < 0 ? "\e[31m" : "\e[0m") # Green / Red / Reset
    reset = "\e[0m"
    "#{color}#{text}#{reset}"
  end

  # --- QUOTE FORMATTER ---
  def self.print_quote(data, symbol)
    # Header Info
    desc = data["descripcionTitulo"]
    price = data["ultimoPrecio"]
    var = data["variacion"]
    time = Time.parse(data["fechaHora"]).strftime("%H:%M:%S") rescue "-"
    
    # Header Layout
    puts "\n" + "="*60
    print " #{symbol.upcase} "
    print " | #{desc[0..35]}" if desc
    puts "\n" + "-"*60
    
    # Big Price & Variation
    price_str = "$ #{currency(price)}"
    var_str   = "#{var > 0 ? '+' : ''}#{var}%"
    puts sprintf(" %-20s %s", price_str, colorize(var_str, var))
    puts " Hora: #{time}"
    puts "="*60

    # Statistics Grid
    # Row 1
    puts sprintf(" %-15s %12s | %-15s %12s", "Apertura:", currency(data["apertura"]), "Maximo:", currency(data["maximo"]))
    # Row 2
    puts sprintf(" %-15s %12s | %-15s %12s", "Cierre Ant:", currency(data["cierreAnterior"]), "Minimo:", currency(data["minimo"]))
    # Row 3 (Volume & Ops)
    puts "-"*60
    puts sprintf(" %-15s %12s | %-15s %12s", "Monto Op ($):", currency(data["montoOperado"], decimals: 0), "Operaciones:", number(data["cantidadOperaciones"]))
    puts "="*60

    # Order Book (Caja de Puntas)
    puntas = data["puntas"]
    
    if puntas && !puntas.empty?
      puts " CAJA DE PUNTAS (T1)"
      puts "-"*60
      # Headers: Qty Buy | Price Buy || Price Sell | Qty Sell
      puts sprintf(" %10s | %10s || %10s | %10s", "Q Compra", "$ Compra", "$ Venta", "Q Venta")
      puts "-"*60

      puntas.each do |p|
        q_buy = number(p["cantidadCompra"])
        p_buy = currency(p["precioCompra"])
        p_sell = currency(p["precioVenta"])
        q_sell = number(p["cantidadVenta"])

        # Skip empty rows (sometimes IOL sends 0s)
        next if p["precioCompra"] == 0 && p["precioVenta"] == 0

        # Colorize Prices only
        c_p_buy = "\e[32m#{p_buy.rjust(10)}\e[0m" # Green
        c_p_sell = "\e[31m#{p_sell.rjust(10)}\e[0m" # Red

        puts sprintf(" %10s | %s || %s | %10s", q_buy, c_p_buy, c_p_sell, q_sell)
      end
    else
      puts " No hay puntas activas."
    end
    puts "="*60 + "\n\n"
  end

  # --- PORTFOLIO FORMATTER ---
  def self.print_portfolio(data)
    country = data["pais"].to_s.split('_').map(&:capitalize).join(' ')
    assets = data["activos"]
    
    if assets.nil? || assets.empty?
      puts "No assets found in #{country} portfolio."
      return
    end

    total_portfolio = assets.sum { |a| a["valorizado"].to_f }

    puts "\n" + "="*95
    puts " PORTFOLIO: #{country.upcase}"
    puts " Total Value: $ #{currency(total_portfolio)}"
    puts "="*95
    
    headers = ["Ticker", "Qty", "Price", "Total Value", "% Port", "Gain $", "Gain %"]
    fmt_str = "%-10s %10s %12s %16s %8s %16s %12s"

    puts fmt_str % headers
    puts "-"*95

    assets.sort_by { |a| -a["valorizado"].to_f }.each do |a|
      ticker = a["titulo"]["simbolo"]
      qty    = a["cantidad"]
      price  = a["ultimoPrecio"]
      val    = a["valorizado"]
      pct    = total_portfolio > 0 ? (val / total_portfolio) * 100 : 0
      gain_d = a["gananciaDinero"]
      gain_p = a["gananciaPorcentaje"]

      f_ticker = ticker[0..9]
      f_qty    = number(qty)
      f_price  = currency(price)
      f_val    = currency(val)
      f_pct    = sprintf("%.2f%%", pct)
      f_gain_d = currency(gain_d)
      f_gain_p = sprintf("%.2f%%", gain_p)

      out_gain_d = colorize(f_gain_d.rjust(16), gain_d)
      out_gain_p = colorize(f_gain_p.rjust(12), gain_p)

      print sprintf("%-10s %10s %12s %16s %8s ", f_ticker, f_qty, f_price, f_val, f_pct)
      puts "#{out_gain_d} #{out_gain_p}"
    end
    puts "-"*95
    puts "\n"
  end

  def self.print_account(data)
    puts "\n" + "="*80
    puts " ACCOUNT SUMMARY"
    puts "="*80
    
    accounts = data["cuentas"]
    puts sprintf("%-30s %-12s %16s %18s", "Type", "Currency", "Available", "Total Value")
    puts "-"*80

    accounts.each do |acc|
      type = acc["tipo"].to_s.gsub('inversion_', '').gsub('_', ' ').capitalize
      currency = acc["moneda"] == "peso_Argentino" ? "ARS" : "USD"
      avail = currency(acc["disponible"])
      total = currency(acc["total"])

      puts sprintf("%-30s %-12s %16s %18s", type, currency, avail, total)
    end
    puts "-"*80
    
    if data["totalEnPesos"]
      puts sprintf("%60s $ %s", "TOTAL (Est. ARS):", currency(data["totalEnPesos"]))
    end
    puts "\n"
  end
end

# --- Main CLI Logic ---

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: iol [command] [options]"

  # General Options
  opts.on("-s", "--symbol SYMBOL", "Stock Symbol") { |v| options[:symbol] = v }
  opts.on("-m", "--market MARKET", "Market") { |v| options[:market] = v }
  opts.on("-t", "--settlement TYPE", "Settlement") { |v| options[:settlement] = v }
  opts.on("-c", "--country COUNTRY", "Country") { |v| options[:country] = v }

  # Asesor Options
  opts.on("-a", "--account NUMBER", "Client Account Number") { |v| options[:account] = v }
  opts.on("--id CLIENT_ID", "Client Internal ID") { |v| options[:client_id] = v }
  opts.on("-q", "--query QUERY", "Search Query") { |v| options[:query] = v }
  
  # Flags
  opts.on("--refresh", "Force refresh of client list") { options[:refresh] = true }
  opts.on("-H", "--human", "Human readable output (Table)") { options[:human] = true }

  # Date/Filter Options
  opts.on("--from DATE", "From Date") { |v| options[:from] = v }
  opts.on("--to DATE", "To Date") { |v| options[:to] = v }
  opts.on("--status STATUS", "Status") { |v| options[:status] = v }
end

command = ARGV.shift
parser.parse!

client = IOLClient.new

def resolve_client_id(client, options)
  return options[:client_id] if options[:client_id]
  raise "Client Account Number (--account) required" unless options[:account]
  client.get_client_id_by_account(options[:account], force_refresh: options[:refresh])
end

# Default Dates
today = Date.today.strftime("%Y-%m-%d")
month_ago = (Date.today - 30).strftime("%Y-%m-%d")

begin
  # Execute Command
  data = case command
  when "quote"
    raise "Symbol required" unless options[:symbol]
    client.get_quote(options[:symbol], market: options[:market] || 'BCBA', settlement: options[:settlement] || 'T1')
  
  when "details"
    raise "Symbol required" unless options[:symbol]
    client.get_financials(options[:symbol], market: options[:market] || 'BCBA')
  
  when "options"
    raise "Symbol required" unless options[:symbol]
    client.get_options(options[:symbol], market: options[:market] || 'BCBA')

  # --- Asesor Commands ---
  when "sync_clients"
    count = client.refresh_client_cache!.size
    { message: "Synced #{count} clients to cache." }

  when "search"
    raise "Query string required (-q)" unless options[:query]
    matches = client.find_clients(options[:query])
    { count: matches.size, results: matches.map { |c| { account: c["numeroCuenta"], name: "#{c['nombre']} #{c['apellido']}", total: c["totalCuentaValorizado"] } } }

  when "aum"
    total = client.calculate_aum
    { currency: "ARS (approx)", total_aum: total, formatted: Formatter.currency(total) }

  when "client_account"
    id = resolve_client_id(client, options)
    client.get_client_account(id)

  when "client_portfolio"
    id = resolve_client_id(client, options)
    client.get_client_portfolio(id, country: options[:country] || "Argentina")

  when "client_transactions"
    id = resolve_client_id(client, options)
    client.get_client_transactions(
      client_id: id,
      from_date: options[:from] || month_ago,
      to_date: options[:to] || today,
      status: options[:status] || "Pendientes",
      country: options[:country] || "Argentina"
    )

  when "client_transfers"
    id = resolve_client_id(client, options)
    client.get_client_transfers(
      id,
      from_date: options[:from] || month_ago,
      to_date: options[:to] || today
    )

  when "help"
    puts parser
    exit
  else
    puts "Unknown command: #{command}"
    puts parser
    exit 1
  end

  # --- Output Logic ---
  if options[:human]
    case command
    when "client_portfolio"
      Formatter.print_portfolio(data)
    when "client_account"
      Formatter.print_account(data)
    when "quote"
      Formatter.print_quote(data, options[:symbol])
    else
      # Fallback to JSON if no specific formatter exists
      puts JSON.pretty_generate(data)
    end
  else
    puts JSON.pretty_generate(data)
  end

rescue StandardError => e
  error_json = { error: true, message: e.message, class: e.class.to_s }
  puts JSON.pretty_generate(error_json)
  exit 1
end