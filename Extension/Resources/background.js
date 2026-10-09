let port;
function connect() {
  port = browser.runtime.connectNative("givemesub");
  port.onMessage.addListener(async (msg) => {
    console.log("native", JSON.stringify(msg));
    const caption = msg.userInfo ?? msg.message ?? msg;
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    for (const tab of tabs) browser.tabs.sendMessage(tab.id, caption).catch(() => {});
  });
  port.onDisconnect.addListener(() => setTimeout(connect, 1000));
}
connect();
