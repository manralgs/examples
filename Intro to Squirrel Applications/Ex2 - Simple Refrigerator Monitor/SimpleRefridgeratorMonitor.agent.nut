// Simple Refrigerator Monitor Application Agent Code
// ---------------------------------------------------

// WEBSERVICE LIBRARY
// ---------------------------------------------------
// Libraries must be required before all other code

// Initial State Library
#require "InitialState.class.nut:1.0.0"


// REFRIGERATOR MONITOR APPLICATION CODE
// ---------------------------------------------------
// Application code, listen for readings from device,
// when a reading is received send the data to Initial 
// State 

class SmartFridge {

    // On Intial State website navigate to "my account" 
    // page find/create a "Streaming Access Key"
    // Paste it into the variable below
    static STREAMING_ACCESS_KEY = "";

    // Class variables
    iState = null;
    agentID = null;

    constructor() {
        // Initialize Initial State
        iState = InitialState(STREAMING_ACCESS_KEY);

        // The Initial State library will create a bucket  
        // using the agent ID 
        agentID = split(http.agenturl(), "/").top();
        // Let's log the agent ID here
        server.log("Agent ID: " + agentID);

        device.on("reading", readingHandler.bindenv(this));
    }

    function readingHandler(reading) {
        // Log the reading from the device. The reading is a 
        // table, so use JSON encodeing method convert to a string
        server.log(http.jsonencode(reading));

        // Initial State requires the data in a specific structre
        // Build an array with the data from our reading.
        local events = [];
        events.push({"key" : "temperature", "value" : reading.temperature, "epoch" : reading.time});
        events.push({"key" : "humidity", "value" : reading.humidity, "epoch" : reading.time});
        events.push({"key" : "door_open", "value" : reading.doorOpen, "epoch" : reading.time});

        // Send reading to Initial State
        iState.sendEvents(events, function(err, resp) {
            if (err != null) {
                // We had trouble sending to Initial State, log the error
                server.error("Error sending to Initial State: " + err);
            } else {
                // A successful send. The response is an empty string, so
                // just log a generic send message
                server.log("Reading sent to Initial State.");
            }
        })
    }

}


// RUNTIME
// ---------------------------------------------------
server.log("Agent running...");

// Run the Application
SmartFridge();
