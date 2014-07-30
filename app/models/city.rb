class City < ActiveRecord::Base
    require 'open-uri'
    require 'json'
    def self.generate_cities
        i =0
        File.open("worldcitiespop.txt").each do |line|
            puts line.inspect
            line.encode!('UTF-8', :undef => :replace, :invalid => :replace, :replace => "")
            row = line.strip.split(",")
            puts row.inspect
            if row[1] != "" && row[4] != "" && row[4] != "0.0"
                city = City.new
                city.tap do |c|
                    c.name = row[1]
                    c.population = row[4]
                    c.latitude = row[5]
                    c.longitude = row[6]
                    c.save
                end
            end

        end
    end

    def self.biggest_cities
        City.order(population: :desc).limit(1000)
    end

    def self.get_timezones
        date = Time.now.to_i
        self.biggest_cities.each do |city|
            url = "https://maps.googleapis.com/maps/api/timezone/json?location=#{city.latitude},#{city.longitude}&timestamp=#{date}&key=AIzaSyBKiF69WTPFEm5_GO7UBahxww1S9psankk"
            @data = JSON.load(open(url))

            city.dst_offset = @data["dstOffset"]
            city.raw_offset = @data["rawOffset"]
            if  @data["dstOffset"] && @data["rawOffset"]
                city.total_offset = @data["dstOffset"] + @data["rawOffset"]
            else
                puts "can't find offset for #{city.id}: #{city.name}!"
            end
            city.timezone = @data["timeZoneId"]
            puts "done with #{city.id}: #{city.name}"
            city.save
        end
    end



    def self.get_sunset_times
        t = Time.now.utc
        self.biggest_cities.each do |city|
            
            puts "getting data for #{city.name}"
            url = "http://api.wunderground.com/api/a112e57999a31e49/astronomy/q/#{city.latitude},#{city.longitude}.json"
            @data = JSON.load(open(url))
        
            #"sunset"=>{"hour"=>"21", "minute"=>"16"}
            sunset = @data["sun_phase"]["sunset"]
            puts "sunset is #{sunset}"
            sunset_raw_utc = Time.utc(t.year, t.month, t.day, sunset["hour"], sunset["minute"])
            if city.total_offset
                city.sunset_utc = sunset_raw_utc.to_i - city.total_offset
                puts "converted to: #{city.sunset_utc}"
            else
                puts "error"
            end
            city.save
            puts "done"

        end
    end

    def self.currently_sunset
        now = Time.now.to_i
        soon = Time.now.to_i + (60*20) #add twenty minutes from now in seconds

        sunset_cities = []
        self.biggest_cities.each do |city|
            if city.sunset_utc && city.sunset_utc < soon && city.sunset_utc >= now
                sunset_cities << [city.latitude, city.longitude, city.name]
            end
        end
        return sunset_cities
    end


end