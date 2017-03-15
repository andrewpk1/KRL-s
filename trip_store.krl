ruleset trip_store {
  	meta {
	    name "trip_store"
	    description <<
	A second Basic ruleset for part 1 of the pico Lab
	>>
	    author "Andrew King"
	    logging on
	    shares __testing, trip_collector, trip_id, long_trip_id
  	}
  	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			 "events": [{"domain" : "car", "type" : "trips_reset"}]}

	    clear_trip = { "_0": { "mileage": "0".as("Number"), "timestamp" : timestamp } }

	    clear_long_trip = { "_0": { "mileage": "0".as("Number"), "timestamp" : timestamp } }

	    trip_id = "0".as("Number")
	    long_trip_id = "0".as("Number")
	}
	rule collect_trips{
		select when explicit trip_processed
		pre{
			passed_mileage = event:attr("mileage").klog("our passed in mileage to be stored: ")
		}
		always{
      		ent:trips := ent:trips.defaultsTo(clear_trip,"initialization was needed");
      		ent:trips{[trip_id,"mileage"]} := passed_mileage;
      		ent:trips{[trip_id,"timestamp"]} := timestamp;
      		trip_id = trip_id + 1
		}
	}

	rule collect_long_trips{
		select when explicit found_long_trip
		pre{
			passed_mileage = event:attr("mileage").klog("our passed in mileage: ")
		}
		always{
			ent:long_trips := ent:long_trips.defaultsTo(clear_long_trip, "initilization was needed");
			ent:long_trips{[long_trip_id,"mileage"]} := passed_mileage;
			ent:long_trips{[long_trip_id,"timestamp"]} := timestamp;
			long_trip_id = long_trip_id + 1
		}
	}
	rule clear_trips{
		select when car trip_reset
		always {
      		ent:trips := clear_trips;
      		ent:long_trips := clear_long_trips
		}
	}
 }