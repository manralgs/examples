# Intro to Squirrel Applications

The examples here range from simple to advanced programming.  Each example builds on the skills learned in the previous example. Please note that the first few examples are not power efficient and will drain battery powered devices quickly. 

## The Basics

### Example 1 - Reading a Sensor

Begin by learning the basics of programming Electric Imp. We will use Electric Imp HTS221 library to take temperature and humidity readings from a sensor. We will also use the Initial State libary to send the data we collect from the sensor to the cloud. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node.  

## Beginner Applications

### Example 2 - Simple Refrigerator Monitor

In this example we will create an simple refrigerator monitoring application that takes synchronous readings from the temperature/humidity sensor and the internal light sensor. The light reading is used to determine if the refrigerator door is open or closed. The door status, temperature and humidity readings are sent to the cloud using the Initial State webservice. We will use a Hardware Abstraction Layer (HAL) to reference all hardware objects, and to organize our application code we will use a class. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node. 

### Example 3 - Simple Remote Monitoring Application

In this example we will create an simple remote monitoring application that takes synchronous readings from multiple sensors and sends them to the cloud using the Initial State webservice. We will use a Hardware Abstraction Layer (HAL) to reference all hardware objects, and to organize our application code we will use a class. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node.  

## Intermediate Applications

### Example 4 - Refrigerator Monitor

In this example we will create a refrigerator monitoring application that takes an asynchronous reading from the temperature/humidity senor. We will use the internal light senor to determine if the refrigerator door is open. We will conserve power by turning off the WiFi and taking readings while offline then connecting periodically to send the readings we have collected to the cloud. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node.  

### Example 5 - Asynchronous Remote Monitoring Application

In this example we will create a remote monitoring application that takes asynchronous sensor readings using the Promise libary. We will conserve power by turning off the WiFi and taking readings while offline then connecting periodically to send the readings we have collected. This code can be easily configured for use with an impExplorer Developer Kit or impAccelerator Battery Powered Sensor Node. 

## Advanced Applications

### Example 6 - Power Efficient Remote Monitoring Application

### Example 7 - Remote Monitoring Application with an Interrupt

### Example 8 - Power Efficient Refrigerator Monitor