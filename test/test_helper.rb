require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

ENV["RACK_ENV"] = "test"

File.delete("elasticsearch.log") if File.exists?("elasticsearch.log")
Tire.configure do
  logger "elasticsearch.log", :level => "debug"
  pretty true
end

if ENV["MONGOID"]
  Mongoid.configure do |config|
    config.connect_to "searchkick_test"
  end

  class Product
    include Mongoid::Document
    # include Mongoid::Attributes::Dynamic
  end

  class Store
    include Mongoid::Document
  end

  class Animal
    include Mongoid::Document
  end

  class Dog < Animal
  end

  class Cat < Animal
  end
else
  require "active_record"

  # for debugging
  # ActiveRecord::Base.logger = Logger.new(STDOUT)

  # rails does this in activerecord/lib/active_record/railtie.rb
  ActiveRecord::Base.default_timezone = :utc
  ActiveRecord::Base.time_zone_aware_attributes = true

  # migrations
  ActiveRecord::Base.establish_connection :adapter => "postgresql", :database => "searchkick_test"

  ActiveRecord::Migration.create_table :products, :force => true do |t|
    t.string :name
    t.integer :store_id
    t.boolean :in_stock
    t.boolean :backordered
    t.integer :orders_count
    t.string :color
    t.decimal :latitude, precision: 10, scale: 7
    t.decimal :longitude, precision: 10, scale: 7
    t.timestamps
  end

  ActiveRecord::Migration.create_table :stores, :force => true do |t|
  end

  ActiveRecord::Migration.create_table :animals, :force => true do |t|
    t.string :name
    t.string :type
  end

  class Product < ActiveRecord::Base
  end

  class Store < ActiveRecord::Base
  end

  class Animal < ActiveRecord::Base
  end

  class Dog < Animal
  end

  class Cat < Animal
  end
end

class Product
  belongs_to :store

  searchkick \
    synonyms: [
      ["clorox", "bleach"],
      ["scallion", "greenonion"],
      ["saranwrap", "plasticwrap"],
      ["qtip", "cottonswab"],
      ["burger", "hamburger"],
      ["bandaid", "bandag"]
    ],
    autocomplete: [:name],
    suggest: [:name, :color],
    conversions: "conversions",
    personalize: "user_ids",
    locations: ["location"]

  attr_accessor :conversions, :user_ids

  def search_data
    attributes.merge conversions: conversions, user_ids: user_ids, location: [latitude, longitude]
  end
end

class Animal
  searchkick
end

Product.searchkick_index.delete if Product.searchkick_index.exists?
Product.reindex
Product.reindex # run twice for both index paths

Animal.reindex

class MiniTest::Unit::TestCase

  def setup
    Product.destroy_all
  end

  protected

  def store(documents, klass = Product)
    documents.shuffle.each do |document|
      klass.create!(document)
    end
    klass.searchkick_index.refresh
  end

  def store_names(names, klass = Product)
    store names.map{|name| {name: name} }, klass
  end

  # no order
  def assert_search(term, expected, options = {})
    assert_equal expected.sort, Product.search(term, options).map(&:name).sort
  end

  def assert_order(term, expected, options = {})
    assert_equal expected, Product.search(term, options).map(&:name)
  end

  def assert_first(term, expected, options = {})
    assert_equal expected, Product.search(term, options).map(&:name).first
  end

end
