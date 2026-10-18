# ShopScroll for iOS

Open `ShopScroll.xcodeproj` in Xcode 26 or later and run the **ShopScroll** scheme on an iPhone simulator. The app targets iOS 17 or later and uses automatic signing. For a physical iPhone, select your Apple development team under **ShopScroll target → Signing & Capabilities**.

The app follows the `../dubhacks26` visual style: cream navigation, plum and coral accents, full-screen product photography, a compact product caption, and a floating heart/share/save rail. Swipe up for the next product, down for the previous one, or sideways to heart and advance. A forward swipe records the product and time viewed. Tap a photo to expand it; double tap to heart it. Details include cart, retailer links, and feed feedback.

## Server connection

Sign in with an account from the sibling web app. The iOS app requests `/user/catalog` and `/user/recommendations` using the account's access token; Search requests `/user/search` and `/user/history-products`. Like, save, skip, and feedback actions are sent to the existing interaction services. Recommendations refresh after those actions. The catalog must contain products; the app shows a retry screen if it cannot load them.

The app defaults to `https://dubhacks26-production.up.railway.app` on both simulator and iPhone. You do not need to run a local server for the app. The Railway catalog route responds and requires a signed-in user. Sign in with an existing ShopScroll account to load products.

To test against the sibling project locally, change **Server settings** on the sign-in screen to `http://localhost:8000` in the simulator, then run:

```sh
cd ../dubhacks26
npm run dev
```

The public Supabase URL and publishable key are bundled in `ServiceConfig.plist`; keep the Supabase secret key **only** in the server environment. The Railway server needs its Supabase configuration, migrations, and a populated `catalog_products` table. The sibling README describes `npm run supabase:push` and the catalog import/embedding commands if you are setting up a new database. An authenticated catalog response has not been verified yet.

Saved collections, cart, budget, and recent history are stored locally per account. Product rows come from the server after sign-in. Access tokens are kept in Keychain and refreshed through Supabase.

## Build

```sh
xcodebuild -project ShopScroll.xcodeproj -scheme ShopScroll -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```
