// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    // State variables
    address public owner;
    uint256 public orderCounter;
    uint256 public constant PLATFORM_FEE_PERCENT = 2; // 2% platform fee
    
    // Structs
    struct Order {
        uint256 orderId;
        address customer;
        address restaurant;
        address driver;
        uint256 amount;
        uint256 tip;
        OrderStatus status;
        uint256 timestamp;
        string deliveryLocation;
    }
    
    struct Restaurant {
        address restaurantAddress;
        string name;
        bool isActive;
        uint256 totalOrders;
        uint256 rating; // Out of 100
    }
    
    struct Driver {
        address driverAddress;
        string name;
        bool isAvailable;
        uint256 totalDeliveries;
        uint256 rating; // Out of 100
        uint256 earnedAmount;
    }
    
    // Enums
    enum OrderStatus {
        Placed,
        Accepted,
        Preparing,
        PickedUp,
        Delivered,
        Cancelled
    }
    
    // Mappings
    mapping(uint256 => Order) public orders;
    mapping(address => Restaurant) public restaurants;
    mapping(address => Driver) public drivers;
    mapping(address => uint256[]) public customerOrders;
    mapping(address => uint256[]) public restaurantOrders;
    mapping(address => uint256[]) public driverOrders;
    
    // Events
    event OrderPlaced(uint256 indexed orderId, address indexed customer, address indexed restaurant, uint256 amount);
    event OrderAccepted(uint256 indexed orderId, address indexed driver);
    event OrderDelivered(uint256 indexed orderId, address indexed driver, uint256 tip);
    event RestaurantRegistered(address indexed restaurant, string name);
    event DriverRegistered(address indexed driver, string name);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredRestaurant() {
        require(restaurants[msg.sender].isActive, "Restaurant not registered or inactive");
        _;
    }
    
    modifier onlyRegisteredDriver() {
        require(bytes(drivers[msg.sender].name).length > 0, "Driver not registered");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        orderCounter = 0;
    }
    
    // Core Function 1: Place Order
    function placeOrder(
        address _restaurant,
        string memory _deliveryLocation
    ) external payable {
        require(msg.value > 0, "Order amount must be greater than 0");
        require(restaurants[_restaurant].isActive, "Restaurant is not active");
        require(bytes(_deliveryLocation).length > 0, "Delivery location required");
        
        orderCounter++;
        
        orders[orderCounter] = Order({
            orderId: orderCounter,
            customer: msg.sender,
            restaurant: _restaurant,
            driver: address(0),
            amount: msg.value,
            tip: 0,
            status: OrderStatus.Placed,
            timestamp: block.timestamp,
            deliveryLocation: _deliveryLocation
        });
        
        customerOrders[msg.sender].push(orderCounter);
        restaurantOrders[_restaurant].push(orderCounter);
        
        emit OrderPlaced(orderCounter, msg.sender, _restaurant, msg.value);
    }
    
    // Core Function 2: Accept and Deliver Order
    function acceptAndDeliverOrder(uint256 _orderId) external onlyRegisteredDriver {
        Order storage order = orders[_orderId];
        require(order.orderId != 0, "Order does not exist");
        require(order.status == OrderStatus.Placed, "Order not available for pickup");
        require(drivers[msg.sender].isAvailable, "Driver not available");
        
        // Accept order
        order.driver = msg.sender;
        order.status = OrderStatus.Accepted;
        drivers[msg.sender].isAvailable = false;
        driverOrders[msg.sender].push(_orderId);
        
        emit OrderAccepted(_orderId, msg.sender);
        
        // Simulate delivery process (in real implementation, this would be separate functions)
        order.status = OrderStatus.Preparing;
        order.status = OrderStatus.PickedUp;
        order.status = OrderStatus.Delivered;
        
        // Process payment
        _processPayment(_orderId);
        
        // Update driver stats
        drivers[msg.sender].isAvailable = true;
        drivers[msg.sender].totalDeliveries++;
        restaurants[order.restaurant].totalOrders++;
        
        emit OrderDelivered(_orderId, msg.sender, order.tip);
    }
    
    // Core Function 3: Register Participants
    function registerRestaurant(string memory _name) external {
        require(bytes(_name).length > 0, "Restaurant name required");
        require(!restaurants[msg.sender].isActive, "Restaurant already registered");
        
        restaurants[msg.sender] = Restaurant({
            restaurantAddress: msg.sender,
            name: _name,
            isActive: true,
            totalOrders: 0,
            rating: 100 // Start with perfect rating
        });
        
        emit RestaurantRegistered(msg.sender, _name);
    }
    
    function registerDriver(string memory _name) external {
        require(bytes(_name).length > 0, "Driver name required");
        require(bytes(drivers[msg.sender].name).length == 0, "Driver already registered");
        
        drivers[msg.sender] = Driver({
            driverAddress: msg.sender,
            name: _name,
            isAvailable: true,
            totalDeliveries: 0,
            rating: 100, // Start with perfect rating
            earnedAmount: 0
        });
        
        emit DriverRegistered(msg.sender, _name);
    }
    
    // Internal function to process payments
    function _processPayment(uint256 _orderId) internal {
        Order storage order = orders[_orderId];
        uint256 totalAmount = order.amount + order.tip;
        uint256 platformFee = (totalAmount * PLATFORM_FEE_PERCENT) / 100;
        uint256 restaurantShare = (order.amount * 70) / 100; // 70% to restaurant
        uint256 driverShare = totalAmount - platformFee - restaurantShare;
        
        // Transfer payments
        payable(order.restaurant).transfer(restaurantShare);
        payable(order.driver).transfer(driverShare);
        // Platform fee stays in contract
        
        drivers[order.driver].earnedAmount += driverShare;
    }
    
    // Additional utility functions
    function addTip(uint256 _orderId) external payable {
        Order storage order = orders[_orderId];
        require(order.customer == msg.sender, "Only customer can add tip");
        require(order.status == OrderStatus.Delivered, "Order must be delivered");
        
        order.tip += msg.value;
        drivers[order.driver].earnedAmount += msg.value;
        payable(order.driver).transfer(msg.value);
    }
    
    function getOrderDetails(uint256 _orderId) external view returns (Order memory) {
        return orders[_orderId];
    }
    
    function getCustomerOrders(address _customer) external view returns (uint256[] memory) {
        return customerOrders[_customer];
    }
    
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner).transfer(balance);
    }
    
    // Emergency functions
    function toggleRestaurantStatus(address _restaurant) external onlyOwner {
        restaurants[_restaurant].isActive = !restaurants[_restaurant].isActive;
    }
    
    function cancelOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.customer == msg.sender || msg.sender == owner, "Unauthorized");
        require(order.status == OrderStatus.Placed, "Cannot cancel order at this stage");
        
        order.status = OrderStatus.Cancelled;
        payable(order.customer).transfer(order.amount);
    }
}
