import consumer from "./consumer";

consumer.subscriptions.create({
    channel: 'GameChannel',
    room: 'Default Room'
}, {
    received(data) {
        console.log("Received data" + data)
    }
});