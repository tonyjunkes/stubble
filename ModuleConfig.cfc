component {
    this.title = "stubble";
    this.author = "Tony Junkes";
    this.webURL = "https://github.com/tonyjunkes/stubble";
    this.description = "A Mustache-inspired template engine for CFML";
    this.version = "0.1.0";
    this.cfmapping = "stubble";
    this.autoMapModels = true;
    this.helpers = ["helpers/StubbleHelper.cfm"];

    function configure() {
        settings = {
            cacheEnabled: true,
            cacheMaxEntries: 200
        };
    }

    function onLoad() {
        var stubble = wirebox.getInstance("Stubble@stubble");
        stubble.configureCache(
            enabled = settings.cacheEnabled,
            maxEntries = settings.cacheMaxEntries
        );
    }

    function onUnload() {
        var stubble = wirebox.getInstance("Stubble@stubble");
        stubble.clearCache();
    }
}
