ruleset echo {
  	meta {
	    name "Echo"
	    description <<
	A Basic ruleset for part 1 of the pico Lab
	>>
	    author "Andrew King"
	    logging on
	    shares __testing
  	}
	global {
	    __testing = {"queries":[{ "name": "__testing" }],
	    			 "events": [{ "domain":  "echo", "type" : "hello"},{"domain" : "echo", "type" : "message", "attrs": ["input"]}]}
	}
	rule hello {
		select when echo hello
		send_directive("say") with
			something = "Hello World"
	}
	rule message{
		select when echo message
		pre{
			passed_input =  event:attr("input").klog("our passed in input: ")
		}
		send_directive("say") with
			something = passed_input
	}
}
