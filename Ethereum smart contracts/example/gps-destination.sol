import 'ROS';
/***
 * This message definition shoult be 
 * autogenerated from ROS message description language.
 * TODO: message generator implementation.
 ***/
contract SatPosition is Message {
    int256 public latitude;
    int256 public longitude;
    function SatPosition(int256 _latitude, int256 _longitude) {
        latitude = _latitude;
        longitude = _longitude;
    }
}
/***
 * This message definition shoult be 
 * autogenerated from ROS message description language.
 * TODO: message generator implementation.
 ***/
contract PathEstimate is Message {
    uint16 public ident;
    SatPosition public base;
    SatPosition public destination;
    function PathEstimate(uint16 _ident, SatPosition _base, SatPosition _destination) {
        ident = _ident;
        base = _base;
        destination = _destination;
    }
}
/***
 * This message definition shoult be 
 * autogenerated from ROS message description language.
 * TODO: message generator implementation.
 ***/
contract PathCost is Message {
    uint16 public ident;
    uint32 public cost;
    function PathCost(uint16 _ident, uint32 _cost) {
        ident = _ident;
        cost = _cost;
    }
}

contract EstimationListener is MessageHandler {
    GPSDestination parent;
    function EstimationListener(GPSDestination _parent) {
        parent = _parent;
    }
    
    function incomingMessage(Message _msg) {
        var cost = PathCost(_msg);
        parent.setEstimateCost(cost.ident(), cost.cost());
    }
}

contract HomebaseListener is MessageHandler {
    GPSDestination parent;
    
    function HomebaseListener(GPSDestination _parent) {
        parent = _parent;
    }
    
    function incomingMessage(Message _msg) {
        SatPosition pos = SatPosition(_msg);
        parent.homebase(pos.longitude(), pos.latitude());
    }
}

contract GPSDestination is ROSCompatible { 
    address dronAccount;
    Publisher estimatePub;
    Publisher targetPub;
    
    address public currentCustomer;
    int256  public homebaseLongitude;
    int256  public homebaseLatitude;
    int256  public destinationLongitude;
    int256  public destinationLatitude;
    uint    public estimatesActualBefore;

    /* Estimates data */

    mapping (address => uint) customerEstimatesOf;

    struct Estimate {
        address customerAddr;
        int256 destinationLongitude;
        int256 destinationLatitude;
        uint cost;
        uint actualBefore; 
    }

    Estimate[] public estimates; 
    
    /* Events */
    event DroneComeback(uint estimateID);
    event EstimateCostReceive(uint estimateID, uint cost);
    
    /* Initial */
    function GPSDestination(int256 _homebaseLongitude,
                            int256 _homebaseLatitude,
                            uint _estimatesActualBefore) {
        dronAccount = msg.sender;
        homebaseLatitude = _homebaseLatitude;
        homebaseLongitude = _homebaseLongitude;
        estimatesActualBefore = _estimatesActualBefore * 1 minutes;
    }
    
    /* ROS integration initial */
    function initROS() returns (bool result) {
        estimatePub = mkPublisher('/path_estimation/path',
                                  'dron_ros_tutorial/PathEstimate');
        targetPub = mkPublisher('/dron_employye/target',
                                'dron_ros_tutorial/SatPosition');
        
        mkSubscriber('/path_estimation/cost',
                     'dron_ros_tutorial/PathCost',
                     new EstimationListener(this));
        mkSubscriber('/dron_employye/homebase',
                     'dron_ros_tutorial/SatPosition',
                     new HomebaseListener(this));
        return true;
    }
    
    /* Drone functions */
    function homebase(int256 _currentLongitude, int256 _currentLatitude) returns(bool result) {
        if(msg.sender==dronAccount) {
        homebaseLongitude = _currentLongitude;
        homebaseLatitude = _currentLatitude;
        uint compliteEstimateID = customerEstimatesOf[currentCustomer];
        currentCustomer = 0x0;
        DroneComeback(compliteEstimateID);
        return true;}
    }

    function setEstimateCost(uint _estimateID, uint _cost) returns(bool result) {
        if(msg.sender==dronAccount) {
            Estimate e = estimates[_estimateID];
            e.cost = _cost;
            EstimateCostReceive(_estimateID, _cost);
            return true;
        }
    }

    /* Customer functions */
    function setNewEstimate(int256 _destinationLongitude,
                            int256 _destinationLatitude) returns(uint estimateID) {
        estimateID = estimates.length++;
        Estimate e = estimates[estimateID];
        e.customerAddr = msg.sender;
        e.destinationLongitude = _destinationLongitude;
        e.destinationLatitude = _destinationLatitude;
        e.actualBefore = now + estimatesActualBefore;
        customerEstimatesOf[msg.sender] = estimateID;
        var base = new SatPosition(homebaseLatitude, homebaseLongitude);
        var target = new SatPosition(_destinationLatitude, _destinationLongitude);
        estimatePub.publish(new PathEstimate(uint16(estimateID), base, target));
        return estimateID;
    }

    function takeFlight() returns(bool result) {
        uint workEstimateID;
        workEstimateID = customerEstimatesOf[msg.sender];
        Estimate e = estimates[workEstimateID];
        if(msg.value>=e.cost) {
        currentCustomer = msg.sender;
        destinationLongitude = e.destinationLongitude;
        destinationLatitude = e.destinationLatitude;
        targetPub.publish(new SatPosition(destinationLongitude, destinationLatitude));
        return true;
        } else msg.sender.send(msg.value);
    }
}
