# -*- coding: utf-8 -*-
require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'hpricot'
require 'open-uri'
require 'time'

DataMapper::setup(:default, ENV['DATABASE_URL'] || 'sqlite3:db.sqlite3')

class Item
  include DataMapper::Resource

  property :guid, String, :key => true
  property :category, String
  property :day, Integer
  property :body, Text, :lazy => false
  property :pubdate, DateTime

  auto_upgrade!
end

def detect_category(str)
  case str
  when /オープニング☆トーク/
    return "opening"
  when /ペラ☆ペラ/
    return "perapera"
  when /プロデューサーのオススメ☆/
    return "recommend"
  else
    return "3pm"
  end
end

def detect_day(str)
  case str
  when /（月/
    return 1
  when /（火/
    return 2
  when /（水/
    return 3
  when /（木/
    return 4
  when /（金/
    return 5
  else
    return 0
  end
end

get '/load_data' do
  doc = Hpricot(open('http://www.tbsradio.jp/kirakira/index.xml'))
  (doc/"item").each do |item|
    guid = item.get_elements_by_tag_name('guid').first.inner_html
    title = item.get_elements_by_tag_name('title').first.inner_html
    pubdate = item.get_elements_by_tag_name('pubdate').first.inner_html
    body = item.to_original_html

    unless Item.get(guid)
      item = Item.new(:guid => guid)
      item.pubdate = pubdate
      item.body = body
      item.category = detect_category(title)
      item.day = detect_day(title)
      item.save
    end
  end

  ""
end

get '/' do
  erb :index
end

get '/index.rss' do
  @wdays = ["日", "月", "火", "水", "木", "金", "土"]
  @categories = {
    "opening" => "オープニング☆トーク",
    "perapera" => "ペラ☆ペラ",
    "3pm" => "3時台コラム",
    "recommended" => "プロデューサーのオススメ☆"
  }

  options = {:limit => 15}
  options[:order] = [:pubdate.desc]
  options[:category] = params[:category] unless params[:category].blank?
  options[:day] = params[:day] unless params[:day].blank?
  @items = Item.all(options)

  content_type 'application/rss+xml', :charset => 'utf-8'
  erb :index_rss
end

helpers do
  def h(str)
    Rack::Utils.escape_html(str)
  end
end
