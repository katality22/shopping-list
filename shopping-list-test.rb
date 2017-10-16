require 'selenium-webdriver'
require 'capybara'
require 'sqlite3'
require 'rspec/expectations'
require 'pp'

$driver = Selenium::WebDriver.for :chrome

class Mainpage
	include RSpec::Matchers

	@@path = 'http://tereshkova.test.kavichki.com/'

	@@item_selector = 'table tr td:nth-child(1)'
	@@qtty_selector = 'table tr td:nth-child(2)'
	@@price_selector = 'table tr td:nth-child(3)'
	
	@@open_link_selector = 'open'
	
	# add form
	@@item_input_selector = 'name'
	@@quantity_input_selector = 'count'
	@@price_input_selector = 'price'
	@@add_button_selector = 'add'
	
	@@driver
	
	def initialize(browser)
		@@driver = browser
		@@driver.get(@@path)
	end

	def table_data_to_hash
		items = $driver.find_elements(:css, @@item_selector) 
		quantity = $driver.find_elements(:css, @@qtty_selector) 
		price = $driver.find_elements(:css, @@price_selector)
		
		rows = Array.new 

		# collect data into hash 
		for i in 0..items.length
			if items[i] 
				if items[i].text.length > 0
				rows[i] = Hash.new
					rows[i][:item] = items[i].text 
					rows[i][:quantity] = quantity[i].text if quantity[i]
					rows[i][:price] = price[i].text if price[i]
				end	
			end
		end

		return rows
	end
	
	def add_new_record
		@@driver.find_element(:id, @@open_link_selector).click
		@@driver.find_element(:id, @@item_input_selector).send_keys('Телепорт')
		@@driver.find_element(:id, @@quantity_input_selector).send_keys('1')
		@@driver.find_element(:id, @@price_input_selector).send_keys('5000')
		@@driver.find_element(:id, @@add_button_selector).click
		items = $driver.find_elements(:css, @@item_selector)
		expect(items.last.text).to eq('Телепорт')
	end
end

class DB
	@@db_name =  "cart.db"

	def self.db_connect
		@@db = SQLite3::Database.new @@db_name
		@@db.results_as_hash = true
	end
	
	def self.db_disconnect
		@@stm.close if @@stm
		@@db.close if @@db
	end
	
	def self.select_all
		self.db_connect
		query="SELECT * FROM Cart"
		@@stm = @@db.prepare query
		rs = @@stm.execute
		result = Array.new
		i = 0
		rs.each do |row|
			result[i] = Hash.new
			result[i][:item] = row['item']
			result[i][:quantity] = row['quantity']
			result[i][:price] = row['price']
			i += 1
		end
		self.db_disconnect
		return result
	end
	
	def self.insert_to_cart(data)
		self.db_connect
		query= self.insert_query_prepare(data)
		@@stm = @@db.prepare query
		rs = @@stm.execute
		self.db_disconnect
	end
	
	# Для упрощения предположим, что данные консистенты, поэтому валидация опущена 
	def self.insert_query_prepare(data)
		query = 'insert into cart values '
		data.each do |row|
			query += "('#{row[:item]}', #{row[:quantity]}, #{row[:price]}), "
		end
		2.times do query.chop!
		end
		puts query
		return query
	end
end

main_page = Mainpage.new($driver)

ui_hash = main_page.table_data_to_hash
puts "COLLECTED DATA FROM UI:\n" + ui_hash.inspect 

DB.insert_to_cart(ui_hash)
db_hash = DB.select_all
puts "\n INSERTED DATA TO THE DB:\n" + db_hash.inspect

main_page.add_new_record

ui_hash = main_page.table_data_to_hash
puts "\n COLLECTED NEW DATA FROM UI: \n" + ui_hash.inspect

ui_list_sorted = ui_hash.sort_by { |hsh| hsh[:item] }
db_list_sorted = db_hash.sort_by { |hsh| hsh[:item] }

pos = ui_list_sorted.length > db_list_sorted.length ? ui_list_sorted.length : db_list_sorted.length

# Проверка по принципу сортировки и сверки каждой строки т.к. нет четкого соответствия между БД и таблицей на сайте (например по ID) и нет гарантии, что одно и то же наименование не встречается несколько раз
for 1i in 0..pos
	if ui_list_sorted[i][:item] != db_list_sorted[i][:item] or ui_list_sorted[i][:quantity] != db_list_sorted[i][:quantity].to_s or ui_list_sorted[i][:price] != db_list_sorted[i][:price].to_s[0..-3]		
		puts "DIFFERENCE DETECTED:\n UI list:"
		pp ui_list_sorted
		puts "DB list:\n"
		pp db_list_sorted
		raise "DB data and Front-end data are not the same. Sorted lists printed in log. Difference starts from the row #{i} (DB: #{db_list_sorted[i].inspect}, UI: #{ui_list_sorted[i].inspect})"
	end
end