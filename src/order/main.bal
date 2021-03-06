import ballerina/http;
import ballerina/log;
import ballerinax/java.jdbc;
import ballerina/'lang\.int as integer;

type Product record {|
    int id;
    string name;
    float price;
|};

type Order record {|
    int id;
    float total;
    boolean processed = false;
    Product[] products;
|};

type Inventory record {|
    int productId;
    int stock;
|};

type OrderEntry record {|
    int productId;
|};

@http:ServiceConfig {
    basePath: "/OrderService"
}
service OrderService on new http:Listener(9091) {  
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getOrder"
    }
    resource function getOrder(http:Caller outboundEP, http:Request req) returns @tainted error? {
        map<anydata> qParams = req.getQueryParams();
        string[] s1 = <string[]> qParams["orderId"];
        string s = s1[0];
        int|error orderId = integer:fromString(s);
        if (orderId is int && orderId > 0) {
            var productIds = getProductIds(orderId);
            if (productIds is int[]) {
                Order|error productOrderFuture = getProductsForOrder(<@untainted> productIds, <@untainted>orderId);
                Inventory[]|error inventoryDetailsFuture = getInventoryForOrder(productIds, orderId);

                // map<Order|Inventory[]|error> result = wait { productOrder: productOrderFuture, inventoryDetails: inventoryDetailsFuture };
                map<json> finalPayload = { orderDetails: "", inventoryDetails: ""};
                var pOrder = productOrderFuture;
                if (pOrder is error) {
                    log:printError("error in retrieving product information.", err = pOrder);
                    respond(outboundEP, "error in retrieving product information.", statusCode = 500);
                } else {
                    json payload = check json.constructFrom(pOrder);
                    finalPayload["orderDetails"] = payload;
                }

                var invDetails = inventoryDetailsFuture;
                if (invDetails is error) {
                    log:printError("error in retrieving inventory information.", err = invDetails);
                    respond(outboundEP, "error in retrieving inventory information.", statusCode = 500);
                } else {
                    json payload = check json.constructFrom(invDetails);
                    finalPayload["inventoryDetails"] = payload;
                }
                respond(outboundEP, <@untainted> finalPayload);
            } else {
                log:printError("error in retrieving product information.", err = productIds);
                    respond(outboundEP, "error in retrieving product information.", statusCode = 500);
            }

        } else {
            log:printError("invalid input query parameter. expected a positive integer.");
            respond(outboundEP, "invalid input query parameter. expected a positive integer.", statusCode = 400);
        }
    }
}

jdbc:Client dbClient = new({
    url: "jdbc:mysql://localhost:3306/testdb",
    username: "root",
    password: "root",
    poolOptions: { maximumPoolSize: 10 },
    dbOptions: { useSSL: false }
});

function getProductIds(int id) returns @tainted int[] | error {
     jdbc:Parameter param = {
        sqlType: jdbc:TYPE_INTEGER,
        value: id
    };
    var result = dbClient->select("SELECT productId FROM ORDERS WHERE orderId = ?", OrderEntry, param);
    if (result is error) {
        return result;
    } else {
        int[] productIds = [];
        foreach var row in result {
            var productId = row["productId"];
            productIds[productIds.length()] = <int> productId;
        }
        return productIds;
    }
}

http:Client productServiceEP = new ("http://localhost:9092");

function getProductsForOrder(int[] ids, int orderId) returns @tainted Order | error {
    float total = 0;
    int count = 0;
    Product[] vProducts = [];
    foreach var id in ids {
        http:Request req = new;
        int pId = check sanitizeInt(id);
        var result = check productServiceEP->get("/ProductService/getProduct?productId=" + pId.toString());
        json payload = check result.getJsonPayload();
        Product product = check Product.constructFrom(payload);
        vProducts[count] = product;
        count = count + 1;
        total = total + product.price; 
    }
    Order productOrder = { id: orderId, total: total, products: vProducts };
    return productOrder;
}

http:Client inventoryServiceEP = new ("http://localhost:9093");

function getInventoryForOrder(int[] ids, int orderId) returns @tainted Inventory[] | error {
    float total = 0;
    int count = 0;
    Inventory[] vInventory = [];
    foreach var id in ids {
        http:Request req = new;
        int pId = check sanitizeInt(id);
        var result = check inventoryServiceEP->get("/InventoryService/checkInventory?productId=" + pId.toString());
        var payload = check result.getJsonPayload();
        Inventory inventory = check Inventory.constructFrom(payload);
        vInventory[count] = inventory;
        count += 1;
    }
    return vInventory;
}

function respond(http:Caller outboundEP, json | string payload, int statusCode = 200) {
    http:Response res = new;
    res.statusCode = statusCode;
    res.setJsonPayload(payload, contentType = "application/json");
    error? responseStatus = outboundEP->respond(res);
    if (responseStatus is error) {
        log:printError("error in sending response.", err = responseStatus);
    }
}

function sanitizeInt(anydata input) returns @untainted int | error {
    if (input is int && input > 0) {
        return input;
    } else {
        log:printError("invalid data. expected a positive integer.");
        error e = error("invalid data");
        return e;
    }
}
