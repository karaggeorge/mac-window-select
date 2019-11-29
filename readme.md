# mac-window-select

> Prompt the user to select a window on macOS, mimicking the native screenshot utility

Requires macOS 10.12 or later. macOS 10.13 or earlier needs to download the [Swift runtime support libraries](https://support.apple.com/kb/DL1998).

## Install

```
$ npm install mac-window-select
```

## Usage

```js
const selectWindow = require('mac-window-select');

selectWindow({appsToIgnore: ['iTerm2']}).then(console.log);

// {
//   canceled: false,
//   window: {
//     ownerName: 'Google Chrome',
//     name: 'karaggeorge/mac-window-select: Select a window on macOS, mimicking the native screenshot utility',
//     y: 23,
//     x: 1920,
//     width: 1920,
//     height: 1057,
//     number: 141349,
//     pid: 69132
//   }
// }

const process = selectWindow().then(console.log);

process.cancel();

// {
//   canceled: true,
//   window: undefined
// }
```

## Demo

<img src="media/demo.gif" width="600">

## API

### `selectWindow(options?: {appsToIgnore: string[]}): PCancelable<Object>`

Trigger the UI to prompt the user to select a window.

Returns `PCancelable<Object>` - Object contains the following:
- `canceled` Boolean - whether or not the process was canceled, either by the user or by calling `.cancel()`
- `window` Object - window that was selected. Will be undefined if the process is canceled or if the module is not supported

The returned promise is an instance of `PCancelable`, so it has a `.cancel()` method which can be used to kill the process

#### `options.appsToIgnore`

Array of app names to ignore. If an app is in this list, it will be ignored and the app below it will be used instead.

Note: Use this if you want your own app to not be selectable

### `selectWindow.isSupported`

Will be `true` if the module is supported (based on macOS version).

## Limitations

Currently, there's no way to track the keyboard events, since the script never steals focus from the previously focused app. If you want Escape to cancel, you have to track it in your app and call the `cancel()` method on the returned promise.

## Related

- [mac-focus-window](https://github.com/karaggeorge/mac-focus-window) - Focus a window and bring it to the front on macOS
- [mac-windows](https://github.com/karaggeorge/mac-windows) - Provide Information about Application Windows running

## License

MIT
