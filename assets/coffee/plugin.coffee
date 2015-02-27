# $("a.download-arrow.arrow-magnet").click(function(e) {
#     e.preventDefault();
#     if (confirm("是否將此 magnet 連結傳送至 NAS 下載")) chrome.extension.connect().postMessage($(this).attr("href"));
#     return false;
# });