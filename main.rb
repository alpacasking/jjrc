# -*- coding: UTF-8 -*-
require 'sinatra'
require 'sinatra/reloader'
require 'rqrcode'
require 'rqrcode_png'
require 'chunky_png'
require 'base64'
require 'securerandom'
require 'mysql2'
require 'active_record'
require 'rubygems'
require 'zip'
require 'fileutils'

# DB設定ファイルの読み込み
ActiveRecord::Base.configurations = YAML.load_file('./database.yml')
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['development'])

class QRCode < ActiveRecord::Base
end

class Device < ActiveRecord::Base
end

$codes=Array.new
$code_number = 0
$isCoding = false
$isSaved = false
#$isDownloading = false

ACTIVE_TIME = 5
=begin
get '/' do
  @code = "0000000001"
  # QRコード画像作成
  qr = RQRCode::QRCode.new( @code, :size => 5, :level => :h )
  @qr_path = qr.to_img.resize(200,200).to_data_url
  #@qr_path ="https://clisawrite.files.wordpress.com/2015/11/not-giant-enough-letter-a.jpg"
  erb :index
end
=end

get '/Edit' do
   erb:code
end

post '/Coding' do
    $isSaved=false
    $codes.clear
    $code_number = params[:code_number].to_i
    for i in 1..$code_number
        randomCode = SecureRandom.random_number(100000000)
        while(QRCode.find_by(id:randomCode) != nil) 
            randomCode = SecureRandom.random_number(100000000)
        end
        $codes.push(randomCode)
    end
    #puts $codes.length
    erb:save
end

post '/Saving' do
    if(!$isSaved) 
        $isSaved=true
        FileUtils.cd('./QRImage')
        FileUtils.rm(Dir.glob('*.*'))
        FileUtils.cd('..')
        for i in 0..$codes.length-1
            qRCode = QRCode.new
            qRCode.id = $codes.at(i)
            qRCode.time = ACTIVE_TIME
            qRCode.save

            filePath = "./QRImage/"
            # QRコード画像作成
            qr = RQRCode::QRCode.new( $codes.at(i).to_s, :size => 5, :level => :h )
            qr.to_img.resize(200,200).save(filePath.concat($codes.at(i).to_s).concat(".png"))

        end
        #puts $codes.length

        directory = './QRImage/' # full path-to-unzipped-dir
        zipfile_name = './QRImage/QRImage.zip' # full path-to-zip-file

        Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
            Dir[File.join(directory, '*')].each do |file|
                zipfile.add(file.sub(directory, ''), file)
            end
        end
    end
    erb:download
end

post '/Download' do
    if File.exist?("./QRImage/QRImage.zip")
        send_file("./QRImage/QRImage.zip",:filename => "QRImage.zip")
    end
    #$isDownloading = false
end


=begin
-3:错误的二维码
-2:已经激活过
-1:激活次数过多
0~:正常激活
=end
post '/' do
    #puts params[:QRCode]
    #puts params[:DeviceID]
    responseText = "0"
    if(Device.find_by(id:params[:DeviceID]) != nil)
        responseText = "-2"
    else
        item = QRCode.find_by(id:(params[:QRCode]).to_i)
        if(item==nil)
            responseText = "-3"
        elsif(item.time<=0)
            responseText = "-1"
        else
            responseText = (item.time-1).to_s
            item.update_attribute(:time,item.time-1)
            device = Device.new
            device.id = params[:DeviceID]
            device.save
        end
    end
    responseText
end