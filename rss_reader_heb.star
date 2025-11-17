"""
Applet: RSS Reader RTL
Summary: RSS Feed Reader with basic Hebrew RTL support
Description: Displays entries from an RSS feed URL. If a title looks like Hebrew, it is rendered right-to-left.
Author: Homertrix/ChatGPT (based on original by Daniel Sitnik)
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("xpath.star", "xpath")

# Cache data for 15 minutes
CACHE_TTL_SECONDS = 900

# Defaults
DEFAULT_FEED_URL = "https://discuss.tidbyt.com/latest.rss"
DEFAULT_FEED_NAME = "RSS Feed"
DEFAULT_ARTICLE_COUNT = "3"

DEFAULT_TITLE_COLOR = "#db7e35"
DEFAULT_TITLE_BG_COLOR = "#333333"
DEFAULT_ARTICLE_COLOR = "#65d1e6"
DEFAULT_CONTENT_COLOR = "#ff8c00"
DEFAULT_FONT = "tb-8"

# A set of Hebrew letters we use for simple detection.
# This is equivalent to checking "ASCII / codepoints" for the Hebrew block.
HEBREW_CHARS = "אבגדהוזחטיךכלםמןנסעףפץצקרשת״׳"

def is_hebrew_text(text, debug_label, debug_hebrew):
    """Return True if the string looks like it contains Hebrew letters."""
    if text == None:
        return False

    for c in text:
        if c in HEBREW_CHARS:
            if debug_hebrew:
                print("HEBREW DETECTED in %s: %s" % (debug_label, text))
            return True

    if debug_hebrew:
        print("NO HEBREW in %s: %s" % (debug_label, text))
    return False

def process_text_for_rtl(text, debug_label, debug_hebrew):
    """If text is Hebrew, reverse it and align right. Otherwise, keep as-is."""
    if text == None:
        return ("", "left")

    if is_hebrew_text(text, debug_label, debug_hebrew):
        # Reverse the string so it reads right-to-left on a left-to-right display.
        return (text[::-1], "right")

    return (text, "left")

def main(config):
    """Main app method.

    Args:
        config (config): App configuration.

    Returns:
        render.Root: Root widget tree.
    """

    # Get config values (all as strings, like the original app)
    feed_url = config.get("feed_url", DEFAULT_FEED_URL)
    feed_name = config.get("feed_name", DEFAULT_FEED_NAME)
    title_color = config.get("title_color", DEFAULT_TITLE_COLOR)
    title_bg_color = config.get("title_bg_color", DEFAULT_TITLE_BG_COLOR)
    article_count = int(config.get("article_count", DEFAULT_ARTICLE_COUNT))
    article_color = config.get("article_color", DEFAULT_ARTICLE_COLOR)
    content_color = config.get("content_color", DEFAULT_CONTENT_COLOR)
    font = config.get("font", DEFAULT_FONT)

    # Booleans are passed as strings when set via config JSON, so normalize.
    show_content_raw = str(config.get("show_content", "false")).lower()
    show_content = show_content_raw == "true"

    debug_hebrew_raw = str(config.get("debug_hebrew", "false")).lower()
    debug_hebrew = debug_hebrew_raw == "true"

    # Fallbacks
    if feed_name == None or feed_name.strip() == "":
        feed_name = "RSS Feed"

    if feed_url == None or feed_url.strip() == "":
        feed_url = DEFAULT_FEED_URL

    # Get feed articles
    articles = get_feed(feed_url, article_count)

    if len(articles) == 0:
        # Show a simple error message instead of returning nothing,
        # so Tidbyt doesn't skip the app.
        return render.Root(
            delay = 100,
            show_full_animation = True,
            child = render.Column(
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Box(
                        width = 64,
                        height = 32,
                        color = "#000000",
                        child = render.Text(
                            content = "No items",
                            font = font,
                            color = "#FFFFFF",
                        ),
                    ),
                ],
            ),
        )

    # Render view
    return render.Root(
        delay = 100,
        show_full_animation = True,
        child = render.Column(
            main_align = "start",
            cross_align = "start",
            children = [
                # Title bar at the top
                render.Box(
                    width = 64,
                    height = 8,
                    color = title_bg_color,
                    child = render.Padding(
                        pad = (1, 1, 1, 1),
                        child = render.Text(
                            content = feed_name,
                            font = font,
                            color = title_color,
                        ),
                    ),
                ),
                # Vertical marquee with the articles
                render.Marquee(
                    width = 64,
                    height = 24,
                    scroll_direction = "vertical",
                    offset_start = 32,
                    offset_end = 0,
                    align = "start",
                    child = render.Column(
                        main_align = "start",
                        cross_align = "start",
                        children = render_articles(
                            articles,
                            show_content,
                            article_color,
                            content_color,
                            font,
                            debug_hebrew,
                        ),
                    ),
                ),
            ],
        ),
    )

def render_articles(articles, show_content, article_color, content_color, font, debug_hebrew):
    """Renders the widgets to display the articles.

    Args:
        articles (list): The list of articles to render.
        show_content (bool): Indicates if the article content should be rendered.
        article_color (str): Color of the article title.
        content_color (str): Color of the article content.

    Returns:
        list: List of widgets.
    """

    widgets = []

    for idx, article in enumerate(articles):
        title_raw = article[0]
        content_raw = article[1]

        # Process title for Hebrew RTL
        title_text, title_align = process_text_for_rtl(
            title_raw,
            "title #%d" % (idx + 1),
            debug_hebrew,
        )

        widgets.append(
            render.WrappedText(
                content = title_text,
                color = article_color,
                font = font,
                width = 64,
                align = title_align,
            ),
        )

        # Optionally render article content (description/body)
        if show_content:
            body_text, body_align = process_text_for_rtl(
                content_raw,
                "content #%d" % (idx + 1),
                debug_hebrew,
            )

            widgets.append(
                render.WrappedText(
                    content = body_text,
                    color = content_color,
                    font = font,
                    width = 64,
                    align = body_align,
                ),
            )

        # Spacer between articles
        widgets.append(
            render.Box(
                width = 64,
                height = 4,
                color = "#000000",
            ),
        )

    return widgets

def get_feed(url, article_count):
    """Retrieves an RSS feed and builds a list with article titles and content.

    Args:
        url (str): The RSS feed URL.
        article_count (int): The number of articles to retrieve from the feed.

    Returns:
        list: List of tuples with (article title, article content).
    """

    res = http.get(url = url, ttl_seconds = CACHE_TTL_SECONDS)
    if res.status_code != 200:
        fail("Request to %s failed with status code: %d: %s" % (url, res.status_code, res.body()))

    articles = []
    data_xml = xpath.loads(res.body())

    for i in range(1, article_count + 1):
        title_query = "//item[%s]/title" % str(i)
        desc_query = "//item[%s]/description" % str(i)

        # Convert result to string and clean up "None"
        title_raw = str(data_xml.query(title_query)).replace("None", "").strip()
        desc_raw = str(data_xml.query(desc_query)).replace("None", "").strip()

        if title_raw == "" and desc_raw == "":
            continue

        articles.append((title_raw, desc_raw))

    return articles

def get_schema():
    """Creates the schema for the configuration screen.

    Returns:
        schema.Schema: The schema for the configuration screen.
    """

    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "feed_url",
                name = "RSS Feed URL",
                desc = "The RSS/Atom URL to read from.",
                icon = "rss",
                default = DEFAULT_FEED_URL,
            ),
            schema.Text(
                id = "feed_name",
                name = "Feed Name",
                desc = "Name to show in the title bar.",
                icon = "font",
                default = DEFAULT_FEED_NAME,
            ),
            schema.Dropdown(
                id = "article_count",
                name = "Article Count",
                desc = "Number of articles to display.",
                icon = "list-ol",
                default = DEFAULT_ARTICLE_COUNT,
                options = [
                    schema.Option(display = "1", value = "1"),
                    schema.Option(display = "2", value = "2"),
                    schema.Option(display = "3", value = "3"),
                    schema.Option(display = "4", value = "4"),
                    schema.Option(display = "5", value = "5"),
                ],
            ),
            schema.Text(
                id = "font",
                name = "Font",
                desc = "Font face to use (e.g. tb-8).",
                icon = "font",
                default = DEFAULT_FONT,
            ),
            schema.Toggle(
                id = "show_content",
                name = "Show article content",
                desc = "Also show the description/body text under each title.",
                icon = "file-alt",
                default = False,
            ),
            schema.Toggle(
                id = "debug_hebrew",
                name = "Debug Hebrew detection",
                desc = "Print detection results to the log.",
                icon = "bug",
                default = False,
            ),
            schema.Color(
                id = "title_color",
                name = "Title Text Color",
                desc = "Color of the feed title text.",
                icon = "brush",
                default = DEFAULT_TITLE_COLOR,
            ),
            schema.Color(
                id = "title_bg_color",
                name = "Title Background Color",
                desc = "Background color of the title bar.",
                icon = "brush",
                default = DEFAULT_TITLE_BG_COLOR,
            ),
            schema.Color(
                id = "article_color",
                name = "Article Title Color",
                desc = "Color of each article's title.",
                icon = "brush",
                default = DEFAULT_ARTICLE_COLOR,
            ),
            schema.Color(
                id = "content_color",
                name = "Article Content Color",
                desc = "Color of each article's content/body.",
                icon = "brush",
                default = DEFAULT_CONTENT_COLOR,
            ),
        ],
    )
