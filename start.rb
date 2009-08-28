require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-timestamps'
require 'haml'
require 'lib/base62'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/urls.sqlite3")

BASE_URL = "http://something.net/"

class Log
  include DataMapper::Resource
  property :id, Serial
  property :ip, String
  property :url_id, String
  property :url, String
  property :created_at, DateTime
  property :updated_at, DateTime
end

class Url
  include DataMapper::Resource
  property :id, Serial
  property :url, String
  property :shorter, String
  property :created_at, DateTime
  property :updated_at, DateTime
  
  after :save, :shorten
  
  def shorten
    if(self.shorter.nil?)
      s = Base62.to_s(self.id)
      self.shorter = s
      self.save
    end
  end
end

DataMapper.auto_upgrade!

helpers do
  def validate_link(link)
    halt 401, 'URL must be full and not local - ie http://something.com' unless valid_url? link
  end
  
  # Determine if a URL is valid.  We run it through 
  def valid_url?(url)
    if url.include? "%3A"
      url = URI.unescape(url)
    end

    retval = true
    
    begin
      uri = URI.parse(URI.escape(url))
      if uri.class != URI::HTTP
        retval = false
      end
      
      host = (URI.split(url))[2]
      if host =~ /^(localhost|192\.168\.\d{1,3}\.\d{1,3}|127\.0\.0\.1|172\.((1[6-9])|(2[0-9])|(3[0-1])).\d{1,3}\.\d{1,3}|10.\d{1,3}\.\d{1,3}.\d{1,3})/
        retval = false
      end
    rescue URI::InvalidURIError
        retval = false
    end
    
    retval
  end
end

get '/' do
  redirect "http://www.google.com"
end

get '/list' do
  @base_url = BASE_URL
  @urls = Url.all
  haml :index
end

get '/log' do
  @logs = Log.all
  haml :report
end

get '/:id' do
  url = Url.get(Base62.to_i(params[:id]))  
  unless url.nil?    
    log = Log.new(:ip=>request.ip, :url_id=>url.id, :url=>url.url)
    log.save
    redirect url.url
  else
    halt 404, "Page not found"
  end
end

get '/show/:id' do
  @base_url = BASE_URL
  @url = Url.get(params[:id])
  haml :show
end

post '/shorten' do
  u = params[:u];
  validate_link u
  existing = Url.first(:url=>u)
  if existing.nil?
    @url = Url.new(:url=>u)
    @url.save
  else
    @url = existing
  end
  redirect "/show/#{@url.id}" 
end