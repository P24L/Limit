# Own Your Bookmarks, Not the App

_ATProto lexicon; PDS-owned records; AppView-gated community lists; web next._

## The Idea
Here’s the itch: I save links everywhere, and every app treats that like a favor I should be grateful for. I don’t want gratitude. I want ownership. So I built bookmarks that live in my PDS, not in some hostage drawer. Lists work like playlists — the same link can sit in Research, Weekend Reads, and Chaos Gremlins at the same time — and everything starts private until I decide otherwise. The lexicon stays deliberately small. If the data can’t walk out the front door with me, I’m not interested.

## How It Feels
You tap “bookmark” in Limit on iOS. If you want, you toss it into a couple of lists. Behind the scenes, a tiny sync engine writes to your repo, retries politely when the network cosplays as dial‑up, and gets out of your way. No mystery boxes, no platform‑flavored lock‑in, just the feeling of putting a sticky note exactly where you’ll find it again.

## Lists, Not Folders
Folders make you pick a single home and then argue with future‑you about where you put things. Lists don’t. They’re light, overlapping, and disposable if they need to be. I support three moods: private (just you), collaborative (invited writers), and public (open to look at). Today it’s your personal mixtapes. Tomorrow it’s community compilations — still yours, just shared, and with house rules.

## Where It Is Now
Right now, the iOS app does the job: save links, organize into your lists, stay fast. It’s the single‑player campaign, tight and focused. Under the hood there are two records — `app.hyper-limit.bookmark` and `app.hyper-limit.bookmark.list` — that map cleanly to what you’d expect: a link with a bit of local context, and a container with a personality. You don’t have to read the lexicons to use it; that’s a feature, not a test.

## Where It’s Going
The next frontier is community lists and the web. Community lists sound simple until you try them without a referee. Who can add? What counts as a duplicate? Which list is the list when two people disagree? That’s where AppView steps in: it gates writes, dedupes noise, and keeps a canonical view so “our list” isn’t Schrödinger’s spreadsheet. In parallel, the web becomes the stage. iOS is perfect for capture, but adoption happens where a link can travel. I want public, browsable list pages, simple embeds, and a place you can sign in from any device and still feel at home.

## Why Bother
Because the internet is still good at two things: dumping information on you and hiding the one link you need right now. Owning your bookmarks is a small act of rebellion with a big payoff. It means your saved things survive app cycles, UI moods, and product sunsets. It also means you can remix them: private notes today, shared lists tomorrow, custom feeds when you’re feeling fancy. Minimal core, maximal composability — boring plumbing so the interesting parts can sing.

## The Vibe
This is utility‑first with dry humor on the edges. Think Swiss Army knife with a playlist button; John Wick for URLs when it needs to be, cardigan‑soft the rest of the time. I’m one developer, which is a constraint and a feature: the iOS side ships fast, and the web is next because that’s where people actually bump into your work.

If this sounds like your flavor of PKM, come along. I’ll keep tuning the iOS flow while I bring the web to life, and community lists will roll in when AppView blows the whistle. Until then, save freely and know it stays yours.

