ruleset trip_store {
  	meta {
	    name "trip_store"
	    description <<
	A second Basic ruleset for part 1 of the pico Lab
	>>
	    author "Andrew King"
	    logging on
	    shares __testing, trip_collector, id
  	}
  	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			 "events": [{"domain" : "echo", "type" : "message", "attrs": ["mileage"]}]}

	    clear_trip = { "_0": { "mileage": "0".as("Number"), "timestamp" : timestamp } }
	    id = "0".as("Number")
	}
	rule collect_trips{
		select when explicit trip_processed
		pre{
			passed_mileage = event:attr("mileage").klog("our passed in mileage: ")
		}
		always{
      		ent:trips := ent:trips.defaultsTo(clear_trip,"initialization was needed");
      		ent:trips{[id,"mileage"]} := passed_mileage;
      		id = id + 1
		}
	}
 }