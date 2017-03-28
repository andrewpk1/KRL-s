ruleset manage_fleet {
  	meta {
	    name "manage_fleet"
	    description <<
	A ruleset for fleet management
	>>
	    author "Andrew King"
	    logging on
	    shares __testing
	    use module io.picolabs.pico alias wrangler
  	}
	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			 "events": [{ "domain":  "car", "type" : "new_vehicle", "attrs":["vehicle_name"]},
	    			 {"domain": "collection", "type" : "empty"},
	    			 {"domain": "car", "type" : "unneeded_vehicle", "attrs":["vehicle_name"]}]}
	    
	    nameFromName = function(vehicle_name) {
  			vehicle_name
		
		}

		showChildren = function() {
  			wrangler:children()
		}

		vehicleByName = function(vehicle_name){
			ent:vehicles[vehicle_name]
		}

		childFromName = function(vehicle_name){
			ent:vehicles[vehicle_name]
		}
	}

	rule add_vehicle {
  		select when car new_vehicle
  		pre {
    		vehicle_name = event:attr("vehicle_name")
    		exists = ent:vehicles >< vehicle_name
    		eci = meta:eci
  		}
  		if exists then
    		send_directive("vehicle_ready")
      			with vehicle_name = vehicle_name
  		fired {
  		} else {
  		vehicle_name.klog("this is the vehicle name:");
    		raise pico event "new_child_request"
      			attributes { "dname": nameFromName(vehicle_name), "color": "#FF69B4", "vehicle_name" : vehicle_name }
  		}
	}


	rule pico_child_initialized {
		select when pico child_initialized
		pre {
	    	the_vehicle = event:attr("new_child")
	    	vehicle_name = event:attr("rs_attrs"){"vehicle_name"}
	  	}
		if vehicle_name.klog("found vehicle_name: ")
			then
     			event:send(
   					{ "eci": the_vehicle.eci, "eid": "install-trip-tracker",
     				"domain": "pico", "type": "new_ruleset",
     				"attrs": { "name": "trip_tracker", 
     					"url": "https://raw.githubusercontent.com/andrewpkbyu/KRL-s/master/trip_tracker.krl", 
     					"vehicle_name": vehicle_name } } )
		fired {
	    	ent:vehicles := ent:vehicles.defaultsTo({});
	    	ent:vehicles{[vehicle_name]} := the_vehicle
	 	}
	}

	rule subscription_module{
		select when child subscription_module_needed
		pre{
			child_eci = event:attr("eci_to_use")
			vehicle_name = event:attr("vehicle_name")
		}
		if child_eci.klog("child to send too:")
			then
				event:send(
   				{ "eci": child_eci, "eid": "install-ruleset",
     				"domain": "pico", "type": "new_ruleset",
     				"attrs": { "rid": "Subscriptions", "name": "Subscriptions", "vehicle_name": vehicle_name } } )
	}
	rule subscription_added {
		select when child send_subscription
		pre{
			child_eci = event:attr("eci_to_use")
			vehicle_name = event:attr("vehicle_name")
		}
		if vehicle_name.klog("final vehicle name to add subscription too:")
			then
			    event:send(
   					{ "eci": child_eci, "eid": "install-trip-store",
     				"domain": "pico", "type": "new_ruleset",
     				"attrs": { "name": "trip_store", 
     					"url": "https://raw.githubusercontent.com/andrewpkbyu/KRL-s/master/trip_store.krl", 
     					"vehicle_name": vehicle_name } } )
		fired{
			raise wrangler event "subscription"
				with name = vehicle_name
     			name_space = "fleet"
     			my_role = "fleet"
     			subscriber_role = "vehicle"
     			channel_type = "subscription"
     			subscriber_eci = child_eci
        }
	}

	rule delete_vehicle {
  		select when car unneeded_vehicle
  		pre {
    		vehicle_name = event:attr("vehicle_name")
    		exists = ent:vehicles >< vehicle_name
    		eci = meta:eci
    		child_to_delete = childFromName(vehicle_name)
    		sub_name = "fleet:" + vehicle+name
 		}
  		if exists then
    		send_directive("vehicle_deleted")
      		with vehicle_name = vehicle_name
  		fired {
  		    child_to_delete.klog("child that is getting deleted:");
  		    raise pico event "delete_child_request"
      			attributes child_to_delete;
  			raise wrangler event "subscription_cancellation"
  				with subscription_name = "fleet:" + vehicle_name;
    		ent:vehicles{[vehicle_name]} := null
  		}
	}

	rule collection_empty {
  		select when collection empty
  		always {
    		ent:vehicles := {}
  		}
	}
}