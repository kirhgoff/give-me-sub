let box, hideTimer, committed = "";

function targetVideo() {
  const videos = [...document.querySelectorAll("video")];
  const playing = videos.filter(v => !v.paused && v.readyState > 2);
  return (playing.length ? playing : videos).sort((a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight)[0];
}

function place() {
  const video = targetVideo();
  if (!video || !box) return;
  const host = document.fullscreenElement || document.webkitFullscreenElement || document.body;
  if (box.parentElement !== host && host !== video) host.appendChild(box);
  const r = video.getBoundingClientRect();
  box.style.left = `${r.left}px`;
  box.style.width = `${r.width}px`;
  box.style.top = `${r.bottom - r.height * 0.12 - box.offsetHeight}px`;
}

browser.runtime.onMessage.addListener((msg) => {
  if (!targetVideo()) return;
  if (!box) {
    box = document.createElement("div");
    box.id = "givemesub-caption";
    box.innerHTML = '<span class="done"></span> <span class="pending"></span>';
    document.body.appendChild(box);
  }
  if (msg.text) committed = (committed + " " + msg.text).trim().split(" ").slice(-18).join(" ");
  box.querySelector(".done").textContent = committed;
  box.querySelector(".pending").textContent = msg.pending || "";
  box.classList.add("visible");
  place();
  clearTimeout(hideTimer);
  hideTimer = setTimeout(() => { box.classList.remove("visible"); committed = ""; }, 4000);
});

["resize", "scroll", "fullscreenchange", "webkitfullscreenchange"].forEach(e => addEventListener(e, place, true));
// ponytail: overlay cannot render when the <video> element itself is fullscreen (Safari native fullscreen); container fullscreen (YouTube etc.) works
