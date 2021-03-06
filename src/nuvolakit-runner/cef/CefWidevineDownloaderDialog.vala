/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CEF
namespace Nuvola {

public class CefWidevineDownloaderDialog : CefPluginDownloaderDialog {

    public CefWidevineDownloaderDialog(CefWidevineDownloader downloader, string web_app_name) {
        bool needs_update = downloader.needs_update();
        Gtk.Label label = Drtgtk.Labels.markup(
            (
                "<b>%s web app requires a proprietary Widevine plugin. Would you like to install it?</b>\n\n"
                + "Upon your approval, Nuvola will download Google Chrome and extract the Widevine plugin. "
                + "You need to accept <a href=\"%s\">Google Chrome End User License Agreement</a> to proceed."
            ),
            web_app_name, CefWidevineDownloader.CHROME_EULA_URL);
        unowned string title = needs_update ? "Widevine Plugin Update Required" : "Widevine Plugin Required";
        base(
            downloader, title, label, "I accept Google Chrome End User License Agreement.",
            needs_update ? "Update plugin" : "Install plugin");
        if (needs_update) {
            warning("Widevine needs update from %s.", downloader.chrome_version);
        } else {
            debug("Need to install Widevine.");
        }
    }
}

} // namespace Nuvola
#endif
