// Remote Monitoring Application With Interrupt Device Code
// --------------------------------------------------------

// SENSOR LIBRARIES
// --------------------------------------------------------
// Libraries must be required before all other code

// Accelerometer Library
#require "LIS3DH.class.nut:1.3.0"
// Temperature Humidity sensor Library
#require "HTS221.device.lib.nut:2.0.1"
// Air Pressure sensor Library
#require "LPS22HB.class.nut:1.0.0"
// Library to help with asynchonous programming
#require "promise.class.nut:3.0.1"
// Library to manage agent/device communication
#require "MessageManager.lib.nut:2.0.0"

// HARDWARE ABSTRACTION LAYER
// --------------------------------------------------------
// HAL's are tables that map human readable names to 
// the hardware objects used in the application. 

// Copy and Paste Your HAL here
// YOUR_HAL <- {...}


// REMOTE MONITORING INTERRUPT APPLICATION CODE
// --------------------------------------------------------
// Application code, take readings from our sensors
// and send the data to the agent 

class Application {

    // Time in seconds to wait between readings
    static READING_INTERVAL_SEC = 30;
    // Time in seconds to wait between connections
    static REPORTING_INTERVAL_SEC = 300;
    // Max number of stored readings
    static MAX_NUM_STORED_READINGS = 20;
    // Time to wait after boot before turning off WiFi
    static BOOT_TIMER_SEC = 60;
    // Accelerometer data rate in Hz
    static ACCEL_DATARATE = 25;

    // Hardware variables
    i2c             = null; // Replace with your sensori2c
    tempHumidAddr   = null; // Replace with your tempHumid i2c addr
    pressureAddr    = null; // Replace with your pressure i2c addr
    accelAddr       = null; // Replace with your accel i2c addr
    wakePin         = null; // Replace with your wake pin

    // Sensor variables
    tempHumid = null;
    pressure = null;
    accel = null;

    // Message Manager variable
    mm = null;
    
    // Flag to track first disconnection
    _boot = false;

    constructor() {
        // Power save mode will reduce power consumption when the 
        // radio is idle. This adds latency when sending data. 
        imp.setpowersave(true);

        // Change default connection policy, so our application 
        // continues to run even if the WiFi connection fails
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

        // Configure message manager for device/agent communication
        mm = MessageManager();
        // Message Manager allows us to call a function when a message  
        // has been delivered. We will use this to know when it is ok
        // to disconnect from WiFi
        mm.onAck(readingsAckHandler.bindenv(this));
        // Message Manager allows us to call a function if a message  
        // fails to be delivered. We will use this to recover data 
        mm.onFail(sendFailHandler.bindenv(this));

        // Initialize sensors
        initializeSensors();

        // Configure different behavior based on the reason the 
        // hardware rebooted 
        checkWakeReason();
    }

    function checkWakeReason() {
        // We can configure different behavior based on 
        // the reason the hardware rebooted. 
        switch (hardware.wakereason()) {
            case WAKEREASON_TIMER :
                // We woke up after sleep timer expired. 
                // No extra config needed.
                break;
            case WAKEREASON_PIN :
                // We woke up because an interrupt pin was triggerd.
                // Let's check our interrupt
                checkInterrupt(); 
                break;
            case WAKEREASON_SNOOZE : 
                // We woke up after connection timeout.
                // No extra config needed.
                break;
            default :
                // We pushed new code or just rebooted the device, etc. Lets
                // congigure everything. 
                server.log("Device running...");
            
                // NV can persist data when the device goes into sleep mode 
                // Set up the table with defaults - note this method will 
                // erase stored data, so we only want to call it when the
                // application is starting up.
                configureNV();

                // We want to make sure we can always blinkUp a device
                // when it is first powered on, so we do not want to
                // immediately disconnect from WiFi after boot
                // Set up first disconnect
                _boot = true;
                imp.wakeup(BOOT_TIMER_SEC, function() {
                    _boot = false;
                    powerDown();
                }.bindenv(this))
        }

        // Configure Sensors to take readings
        configureSensors();
        takeReadings();

    }

    function takeReadings() {
        // Take readings by building an array of functions that all  
        // return promises. 
        local series = [takeTempHumidReading(), takePressureReading(), takeAccelReading()];
        
        // The all method executes the series of promises in parallel 
        // and resolves when they are all done. It Returns a promise 
        // that resolves with an array of the resolved promise values.
        Promise.all(series)
            .then(function(results) {
                // Create a table to store the results from the sensor readings
                // Add a timestamp 
                local reading = {"time" : time()};
                // Add all successful readings
                if ("temperature" in results[0]) reading.temperature <- results[0].temperature;
                if ("humidity" in results[0]) reading.humidity <- results[0].humidity;
                if ("pressure" in results[1]) reading.pressure <- results[1].pressure;
                if ("x" in results[2]) reading.accel_x <- results[2].x; 
                if ("y" in results[2]) reading.accel_y <- results[2].y; 
                if ("z" in results[2]) reading.accel_z <- results[2].z; 
                // Add table to the readings array for storage til next connection
                nv.readings.push(reading);

                return("Readings Done");
            }.bindenv(this))
            .finally(checkConnetionTime.bindenv(this))
    }

    function takeTempHumidReading() {
        return Promise(function(resolve, reject) {
            tempHumid.read(function(result) {
                return resolve(result);
            }.bindenv(this))
        }.bindenv(this))
    }

    function takePressureReading() {
        return Promise(function(resolve, reject) {
            pressure.read(function(result) {
                return resolve(result);
            }.bindenv(this))
        }.bindenv(this))
    }

    function takeAccelReading() {
        return Promise(function(resolve, reject) {
            accel.getAccel(function(result) {
                return resolve(result);
            }.bindenv(this))
        }.bindenv(this))
    }

    function checkConnetionTime(value = null) {
        // Grab a timestamp
        local now = time();

        // Update the next reading time varaible
        setNextReadTime(now);
        
        local connected = server.isconnected();
        // Only send if we are already connected 
        // to WiFi or if it is time to connect
        if (connected || timeToConnect()) {

            // Update the next connection time varaible
            setNextConnectTime(now);

            // We changed the default connection policy, so we need to 
            // use this method to connect
            if (connected) {
                sendData();
            } else {
                server.connect(function(reason) {
                    if (reason == SERVER_CONNECTED) {
                        // We connected let's send readings
                        sendData();
                    } else {
                        // We were not able to connect
                        // Let's make sure we don't run out 
                        // of meemory with our stored readings
                        failHandler();
                    }
                }.bindenv(this));
            }

        } else {
            // Not time to connect, let's sleep until
            // next reading time
            powerDown();
        }
    }

    function sendData() {
        local data = {};

        if (nv.readings.len() > 0) {
            data.readings <- nv.readings;
        }
        if (nv.alerts.len() > 0) {
            data.alerts <- nv.alerts;
        }

        // Send data to the agent   
        mm.send("data", data);

        // Clear readings we just sent, we can recover
        // the data if the message send fails
        nv.readings.clear();

        // Clear alerts we just sent, we can recover
        // the data if the message send fails
        nv.alerts.clear();

        // If this message is acknowleged by the agent
        // the readingsAckHandler will be triggered
        
        // If the message fails to send we will handle 
        // in the sendFailHandler handler
    }

    function readingsAckHandler(msg) {
        // We connected successfully & sent data

        // Reset numFailedConnects
        nv.numFailedConnects <- 0;
        
        // Disconnect from server
        powerDown();
    }

    function sendFailHandler(msg, error, retry) {
        // Message did not send, pass them the 
        // the connection failed handler, so they
        // can be condensed and stored
        failHandler(msg.payload.data);
    }

    function powerDown() {
        // Power Down sensors
        powerDownSensors();

        // Calculate how long before next reading time
        local timer = nv.nextReadTime - time();
    
        // Check that we did not just boot up and are 
        // not about to take a reading
        if (!_boot && timer > 2) {
            // Go to sleep
            if (server.isconnected()) {
                imp.onidle(function() {
                    // This method flushes server before sleep
                    server.sleepfor(timer);
                }.bindenv(this));
            } else {
                // This method just put's the device to sleep
                imp.deepsleepfor(timer);
            }
        } else {
            // Schedule next reading, but don't go to sleep
            imp.wakeup(timer, function() {
                powerUpSensors();
                takeReadings();
            }.bindenv(this));
        }
    }

    function powerDownSensors() {
        tempHumid.setMode(HTS221_MODE.POWER_DOWN);
    }
    
    function powerUpSensors() {
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
    }

    function failHandler(data = null) {
        // We are having connection issues
        // Let's condense and re-store the data

        // Find the number of times we have failed
        // to connect (use this to determine new readings 
        // previously condensed readings) 
        local failed = nv.numFailedConnects;
        local readings;
        
        // Connection failed before we could send
        if (data == null) {
            // Make a copy of the stored readings
            readings = nv.readings.slice(0);
            // Clear stored readings
            nv.readings.clear();
        } else {
            if ("readings" in data) readings = data.readings;
            if ("alerts" in data) nv.alerts <- data.alerts;
        }

        if (readings.len() > 0) {
            // Create an array to store condensed readings
            local condensed = [];

            // If we have already averaged readings move them
            // into the condensed readings array
            for (local i = 0; i < failed; i++) {
                condensed.push( readings.remove(i) );
            }

            // Condense and add the new readings 
            condensed.push(getAverage(readings));
        
            // Drop old readings if we are running out of space
            while (condensed.len() >= MAX_NUM_STORED_READINGS) {
                condensed.remove(0);
            }

            // If new readings have come in while we were processing
            // Add those to the condensed readings
            if (nv.readings.len() > 0) {
                foreach(item in nv.readings) {
                    condensed.push(item);
                }
            }

            // Replace the stored readings with the condensed readings
            nv.readings <- condensed;
        } 

        // Update the number of failed connections
        nv.numFailedConnects <- failed++;
    }

    function getAverage(readings) {
        // Variables to help us track readings we want to average
        local tempTotal = 0;
        local humidTotal = 0;
        local pressTotal = 0;
        local tCount = 0;
        local hCount = 0;
        local pCount = 0;

        // Loop through the readings to get a total
        foreach(reading in readings) {
            if ("temperature" in reading) {
                tempTotal += reading.temperature;
                tCount ++;
            }
            if ("humidity" in reading) {
                humidTotal += reading.humidity;
                hCount++;
            }
            if ("pressure" in reading) {
                pressTotal += reading.pressure;
                pCount++;
            }
        }

        // Grab the last value from the readings array
        // This we allow us to keep the last accelerometer 
        // reading and time stamp
        local last = readings.top();

        // Update the other values with an average 
        last.temperature <- tempTotal / tCount;
        last.humidity <- humidTotal / hCount;
        last.pressure <- pressTotal / pCount;

        // return the condensed single value
        return last
    }

    function configureNV() {
        local root = getroottable();
        if (!("nv" in root)) root.nv <- {};

        local now = time();
        setNextConnectTime(now); 
        setNextReadTime(now);
        nv.readings <- [];
        nv.alerts <- [];
        nv.numFailedConnects <- 0;
    }

    function setNextConnectTime(now) {
        nv.nextConectTime <- now + REPORTING_INTERVAL_SEC;
    }

    function setNextReadTime(now) {
        nv.nextReadTime <- now + READING_INTERVAL_SEC;
    }

    function timeToConnect() {
        // return a boolean - if it is time to connect based on 
        // the current time or alerts
        return (time() >= nv.nextConectTime || nv.alerts.len() > 0);
    }

    function configureInterrupt() {
        accel.configureInterruptLatching(true);
        accel.configureFreeFallInterrupt(true);
        
        // Configure wake pin
        wakePin.configure(DIGITAL_IN_WAKEUP, function() {
            if (wakePin.read()) {
                checkInterrupt();
                checkConnetionTime();
            }
        }.bindenv(this));
    }

    function checkInterrupt() {
        local interrupt = accel.getInterruptTable();
        if (interrupt.int1) {
            nv.alerts.push({"msg" : "Freefall Detected", "time": time()});
        }
    }

    function initializeSensors() {
        // Configure i2c
        i2c.configure(CLOCK_SPEED_400_KHZ);

        // Initialize sensors
        tempHumid = HTS221(i2c, tempHumidAddr);
        pressure = LPS22HB(i2c, pressureAddr);
        accel = LIS3DH(i2c, accelAddr);
    }

    function configureSensors() {
        // Configure sensors to take readings
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        pressure.softReset();
        pressure.enableLowCurrentMode(true);
        pressure.setMode(LPS22HB_MODE.ONE_SHOT);
        accel.init();
        accel.setLowPower(true);
        accel.setDataRate(ACCEL_DATARATE);
        accel.enable(true);
        // Configure accelerometer freefall interrupt 
        configureInterrupt();
    }
}


// RUNTIME 
// ---------------------------------------------------

// Initialize application to start readings loop
app <- Application();
