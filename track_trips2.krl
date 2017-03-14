ruleset track_trips {
  	meta {
	    name "track_trips"
	    description <<
	A second Basic ruleset for part 1 of the pico Lab
	>>
	    author "Andrew King"
	    logging on
	    shares __testing
  	}
	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			 "events": [{"domain" : "car", "type" : "new_trip", "attrs": ["mileage"]}]}
	}
	rule process_trip{
		select when car new_trip
		pre{
			passed_mileage =  event:attr("mileage").klog("our passed in mileage: ")
		}
		send_directive("trip") with
			trip_length = passed_mileage + " miles"
	}
}
