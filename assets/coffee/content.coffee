String::capitalize = ->
    @replace /^./, (match) ->
        match.toUpperCase()

Preference =
    cache: {}
    template:
        synology:
            ip: "192.168.1.1"
            port: 5000
            url: "/webman/3rdparty/DownloadStation/dlm/downloadman.cgi"
            tokenUrl: "/webman/login.cgi"
            indexUrl: "/webman/index.cgi"
        transmission:
            ip: "192.168.1.1"
            port: 9091
            url: "/transmission/rpc"

    initialize: () ->
        for key,value of localStorage
            Preference.cache[key] = value
            if location.href.indexOf(chrome.runtime.id + "/preferences")
                $("#pref" + key.capitalize() ).val(value)
        if (Preference.get("type") != "synology")
            $(".form-group.synology").hide()
        if (Preference.get("type") != "transmission")
            $(".form-group.transmission").hide()

        return
    get: (key) ->
        if (Preference.cache.hasOwnProperty(key)) then Preference.cache[key] else Preference.cache[key] = localStorage[key]
    set: (key, value) ->
        localStorage[key] = value
        Preference.cache[key] = value
    clearCache: () ->
        localStorage.clear()
        Preference.cache = {}
    bind: () ->
        $("#fetchToken").click ->
            if $("#prefType").val() == "synology"
                client = new SynologyClient
            else if $("#prefType").val() == "transmission"
                client = new TransmissionClient

            client.fetchToken()
            return
        $("#prefType").change ->
            type = $(this).val()
            template = Preference.template[type]
            $("#prefPort").val(template.port)
            $("#prefUrl").val(template.url)
            $("#prefToken").val("")

        $("#prefSave").click ->
            Preference.clearCache()
            Preference.set("type", $("#prefType").val())
            Preference.set("ip", $("#prefIp").val())
            Preference.set("port", $("#prefPort").val())
            Preference.set("url", $("#prefUrl").val())
            Preference.set("token", $("#prefToken").val())
            # Preference.set("location", $("#prefLocation").val())
            alert(chrome.i18n.getMessage("prefSaveComplete"))


Localize =
    init: () ->
        $('[i18n-content]').each((index, element) ->
            element.innerHTML = chrome.i18n.getMessage($(this).attr('i18n-content'))
        )
        return
    bind: () ->
        document.addEventListener 'DOMContentLoaded', Localize.init

class Client
    constructor: ->

    fetchToken: ->

    send: (url) ->

class SynologyClient extends Client
    constructor: ->

    fetchToken: ->
        targetUrl = "http://#{Preference.get("ip")}:#{Preference.get("port")}#{Preference.template.synology.tokenUrl}"
        http = new XMLHttpRequest()

        http.open("POST", targetUrl, true)

        http.onreadystatechange = () ->
            if http.readyState == 4 && http.status == 200
                json = JSON.parse(http.responseText)
                if json.SynoToken
                    $("#prefToken").val(json.SynoToken)
                else
                    alert(chrome.i18n.getMessage("prefNeedLoginSynology"))
                    chrome.tabs.create({url: "http://#{Preference.get("ip")}:#{Preference.get("port")}#{Preference.template.synology.indexUrl}"})

        http.send()
    send: (url) ->
        targetUrl = "http://#{Preference.get("ip")}:#{Preference.get("port")}#{Preference.get("url")}"
        params = ""
        http = new XMLHttpRequest()

        http.open("POST", targetUrl, true)
        http.setRequestHeader("X-SYNO-TOKEN", Preference.get("token"))
        # desttext = Preference.get("location")
        desttext = ""
        params = "action=add_url_task&desttext=#{desttext}&file_info=on&urls=%5B%22" + encodeURIComponent(url) + "%22%5D";
        http.onreadystatechange = () ->
            if http.readyState == 4 && http.status == 200
                json = JSON.parse(http.responseText)
                if json.success == true
                    alert chrome.i18n.getMessage("magnetAddSuccess")
                    # successCallback?
                else
                    # failCallback?
                    alert JSON.stringify(json)
                    chrome.tabs.create({url: "chrome-extension://#{chrome.runtime.id}/preferences.html"})
        http.send(params);

class TransmissionClient extends Client
    constructor: ->

    fetchToken: ->
        targetUrl = "http://#{$("#prefIp").val()}:#{$("#prefPort").val()}#{Preference.template.transmission.url}"
        http = new XMLHttpRequest()
        http.open("POST", targetUrl, true)
        http.setRequestHeader("Content-Type", "application/json")
        params =
            "method": "torrent-add"

        params = JSON.stringify(params)
        http.onreadystatechange = () ->
            if http.readyState == 4 && http.status == 409
                match = http.responseText.toString().match(/<code>.*?: (.*?)<\/code>/)
                if (match[1])
                    $("#prefToken").val(match[1])
        http.send()

    send: (url) ->
        targetUrl = "http://#{Preference.get("ip")}:#{Preference.get("port")}#{Preference.get("url")}"
        params = ""
        http = new XMLHttpRequest()

        http.open("POST", targetUrl, true)
        http.setRequestHeader("Content-Type", "application/json")
        http.setRequestHeader("X-Transmission-Session-Id", Preference.get("token"))
        params =
            "method": "torrent-add"
            "arguments":
                "paused": false
                "filename": url

        params = JSON.stringify(params)
        http.onreadystatechange = () ->
            if http.readyState == 4 && http.status == 200
                json = JSON.parse(http.responseText)
                if json.result == "success"
                    alert chrome.i18n.getMessage("magnetAddSuccess")
                else
                    alert JSON.stringify(json)
                    chrome.tabs.create({url: "chrome-extension://#{chrome.runtime.id}/preferences.html"})

        http.send(params);

Magnet =
    init: () ->

        if chrome.contextMenus
            chrome.contextMenus.create(
                'title': chrome.i18n.getMessage("contextMenusLabel")
                'documentUrlPatterns': ['http://*/*', 'https://*/*']
                'contexts': ['link']
                'id': '0'
                () ->
            )
            if (!chrome.contextMenus.onClicked.hasListeners())
                chrome.contextMenus.onClicked.addListener(Magnet.handler);

    handler: (info, tab) ->
        url = info.srcUrl;
        if url == undefined
            url = info.linkUrl;
        if !url
            return
        bg = chrome.extension.getBackgroundPage()
        bg.Magnet.send(url)

    send: (url) ->

        if Preference.cache.type == "synology"
            client = new SynologyClient
        else if Preference.cache.type == "transmission"
            client = new TransmissionClient

        client.send(url)

        return


Localize.bind()
Magnet.init()
$ ->
    Preference.initialize()
    Preference.bind()

# chrome.extension.onConnect.addListener (port) ->
#     port.onMessage.addListener (url) ->
#         Magnet.send(url)

chrome.browserAction.onClicked.addListener (tab) ->
    chrome.tabs.create({url: "chrome-extension://#{chrome.runtime.id}/preferences.html"})
