[Audrie Gordon](https://www.youtube.com/watch?v=lhE9QfcoYYM&list=LL0g8vfZ0StQCzN4W6-szw0w&index=2&t=0s)

[My ISS App](https://apps.powerapps.com/play/903d427e-017f-45c4-a47d-f80cf7b3e151?tenantId=800d472c-8288-4f27-8978-f726a7a3d1f0)

[ISS Public API](https://wheretheiss.at/w/developer)

[BingMaps API Pushpin Icon Styles](https://docs.microsoft.com/en-us/bingmaps/rest-services/common-parameters-and-types/pushpin-syntax-and-icon-styles)

```
{
  "name": "iss",
  "id": 25544,
  "latitude": -4.2664261695523,
  "longitude": 88.76437602115,
  "altitude": 422.19181098296,
  "velocity": 27562.799873106,
  "visibility": "eclipsed",
  "footprint": 4518.5976436872,
  "timestamp": 1571780359,
  "daynum": 2458779.4023032,
  "solar_lat": -11.188830567319,
  "solar_lon": 211.28952376768,
  "units": "kilometers"
}

//onstart
Set(apiresponse, iss25544.Run()) 

//image
If(apiresponse.visibility="daylight",issday,issnight)

//map
BingMaps.GetMapV2(
    "AerialWithLabels",
    4,
    apiresponse.latitude,
    apiresponse.longitude,
    {
        pushpinLabel: apiresponse.name & " " & apiresponse.id,
        pushpinIconStyle: 38,
        pushpinLatitude: apiresponse.latitude,
        pushpinLongitude: apiresponse.longitude
    }
)

//fontcolor
If(apiresponse.visibility="daylight",RGBA(0, 0, 0, 1),RGBA(255, 255, 255, 1))

//labels
apiresponse.name& " " & apiresponse.id
"Date: " & Now()
"Latitude: " & apiresponse.latitude
"Longitude: " & apiresponse.longitude
"Altitude: " & apiresponse.altitude
"Velocity: " & apiresponse.velocity
"Visibility: " & apiresponse.visibility
```