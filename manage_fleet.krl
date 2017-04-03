ruleset manage_fleet {
  	meta {
	    name "manage_fleet"
	    description <<
	A ruleset for fleet management
	>>
	    author "Andrew King"
	    logging on
	    shares __testing, nameFromName, showChildren, vehicleByName, childFromName, fleet_report, vehicles, clear_reports, last_5, clear_report
	    provides __testing, nameFromName, showChildren, vehicleByName, childFromName, fleet_report, vehicles
	    use module Subscriptions
	    use module io.picolabs.pico alias wrangler
  	}
	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			"events": [{ "domain":  "car", "type" : "new_vehicle", "attrs":["vehicle_name"]},
	    			{"domain": "collection", "type" : "empty"},
	    			{"domain": "car", "type" : "unneeded_vehicle", "attrs":["vehicle_name"]},
	    			{"domain": "report", "type": "func"},
	    			{"domain": "vehicles", "type": "func"},
	    			{"domain": "report", "type" : "begin"},
	    			{"domain": "last_5", "type" : "func"}]}

	    clear_reports = {} 

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

		vehicles = function(){
			relevant_vehicles = Subscriptions:getSubscriptions().filter(function(v){v{"attributes"}{"subscriber_role"} == "vehicle"});
			relevant_vehicles
		}

		fleet_report = function(){
			relevant_subs = vehicles();
			report = relevant_subs.map(function(v){
				Subscriptions:skyQuery(v{"attributes"}{"subscriber_eci"}, "trip_store","trips", {})
			});
			report
		}

		create_report = function(id, trips){
			inner_report = {"vehicles" : vehicles().keys().length(),
                			"responding" : 0,
                			"trips" : trips};
            inner_report.klog("I am an inner report: ");
            trip_no = id.split(re#_#)[1];
            trip_no = "report_" + trip_no;
            trip_no.klog("I am the trip_no: ");
			report = {}.put(id,inner_report);
			report.klog("I am a report: ");
            report
		}

		last_5 = function(){
			len = ent:reports.keys().length();
			reports = 
				(len <= 5) => ent:reports
                   | {}.put(ent:reports.keys()[len-5],ent:reports{ent:reports.keys()[len-5]}).put(ent:reports.keys()[len-4],ent:reports{ent:reports.keys()[len-4]}).put(ent:reports.keys()[len-3],ent:reports{ent:reports.keys()[len-3]}).put(ent:reports.keys()[len-2],ent:reports{ent:reports.keys()[len-2]}).put(ent:reports.keys()[len-1],ent:reports{ent:reports.keys()[len-1]})
		}

		highest_report_num = function(){
			len = ent:reports.keys().length();
			keys = ent:reports.keys();
			lastkey = ent:reports.keys()[len-1].defaultsTo("0_0");
			report_num = lastkey.split(re#_#)[1];
			report_num.klog("HIGHEST REPORT NUM");
			report_num
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
      			attributes { "dname": nameFromName(vehicle_name), "color": "#FF69B4", "vehicle_name" : vehicle_name}
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
	    	ent:vehicles{[vehicle_name]} := th/e_vehicle
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

	rule start_fleet_report{
		select when report begin
		foreach vehicles() setting(vehicle)
		pre{
			child_eci = vehicle{"attributes"}{"subscriber_eci"}
			report_num = highest_report_num().as("Number") + 1
		}
		if report_num.klog("sending event to child with report num: ")
			then
				event:send(
   					{ "eci": child_eci, "eid": "fleet request",
   					"domain": "report", "type": "request",
   					"attrs": { "name": "report_request", "report_num" : report_num } } )
	} 

	rule report_incoming {
		select when child reporting
		pre{
			id = event:attr("cor_id")
			trips = event:attr("trips")
			report = create_report(id, trips)
			trip_no = id.split(re#_#)[1]
            trip_no = "report_" + trip_no
		}
	    always{
	    	ent:reports := ent:reports.defaultsTo(clear_reports, "initializing reports");
	    	ent:reports := ent:reports.put([trip_no], report);
	    	ent:reports.klog("report:");
	    	raise increment event "report"
	    		attributes {"trip_no" : trip_no}

	    }
	}

	rule increment_report{
		select when increment report
		foreach ent:reports{event:attr("trip_no")}.keys() setting (key)
			pre{
				trip_no = event:attr("trip_no")
			}
			always{
				key.klog("foreaching with this key:");
				ent:reports{[trip_no, key, "responding"]} := ent:reports{trip_no}.keys().length()
			}
	}
	rule collection_empty {
  		select when collection empty
  		always {
    		ent:reports := clear_reports
  		}
	}

	rule test_report_func {
		select when report func
		pre{
			report = fleet_report()
		}
		if report.klog("this is the returned information:")
			then
				noop()
	}
	rule test_vehicles_func {
		select when vehicles func
		pre{
			relevant_vehicles = vehicles()
		}
		if relevant_vehicles.klog("this is the subscribed vehicles")
			then
				noop()
	}
	rule test_last_5_func {
		select when last_5 func
		pre{
			last5 = last_5()
		}
		if last5.klog("this is the last 5 reports up in here")
			then
				noop()
	}
}