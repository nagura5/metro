require 'httpclient'
require 'sinatra'
require 'yaml'
require 'date'
require 'json'



API_ENDPOINT   = 'https://api.tokyometroapp.jp/api/v2/'
DATAPOINTS_URL = API_ENDPOINT + "datapoints"
ACCESS_TOKEN   = 'a95e568cde6a945c8aa8c26ab53b2894de2fd33953698b1e8aafdd692bfbe2be'


STATION_LIST   = YAML.load_file('stationList.yaml')





def get_stations(station_name)

  result = []
  STATION_LIST.each do |station|
    result << station if station_name==station["name"]
  end
  result
end



def get_station_name(odpt_station_name)
  STATION_LIST.each do |station|
    return station["name"] if odpt_station_name==station["odpt_name"]
  end
  nil
end


get '/' do

  erb :index
end


post '/' do


  odpt_station_list = get_stations(params[:stationName].gsub("駅",""))


  now = DateTime.now.new_offset(Rational(9, 24))

  @results = []

  http_client = HTTPClient.new

  odpt_station_list.each do |station|
    response = http_client.get DATAPOINTS_URL,
      {"rdf:type"=>"odpt:StationTimetable",
       "odpt:station"=>station["odpt_name"],
       "acl:consumerKey"=>ACCESS_TOKEN}

    JSON.parse(response.body).each do |station_timetable|




      timetable = case now.wday
                  when 0
                    station_timetable["odpt:holidays"]
                  when 6
                    station_timetable["odpt:saturdays"]
                  else
                    station_timetable["odpt:weekdays"]
                  end

      timetable.each do |time|


        hour, min = time["odpt:departureTime"].split(":").map{|num| num.to_i}

        timetable_datetime = DateTime.new(now.year, now.month, now.day, hour, min, 0, "+9")


        timetable_datetime.next_day if hour <= 2

        next if now >= timetable_datetime


        @results << {"name"=>station["name"],
                     "line_name"=>station["line"],
                     "time"=>time["odpt:departureTime"],
                     "dest"=>get_station_name(time["odpt:destinationStation"])}
        break
      end
    end
  end

  erb :show
end
