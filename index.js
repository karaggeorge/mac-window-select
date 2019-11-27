'use strict';
const path = require('path');
const execa = require('execa');
const electronUtil = require('electron-util/node');
const macosVersion = require('macos-version');
const PCancelable = require('p-cancelable');

const binary = path.join(electronUtil.fixPathForAsarUnpack(__dirname), 'window-select');

const isSupported = macosVersion.isGreaterThanOrEqualTo('10.14.4');

module.exports = ({appsToIgnore} = {appsToIgnore: []}) => new PCancelable(async (resolve, reject, onCancel) => {
	if (!isSupported) {
		resolve({canceled: false, window: undefined});
	}

	const worker = execa(binary, [
		'select',
		'-j',
		...appsToIgnore.reduce((acc, app) => [...acc, '-i', app], [])
	]);

	onCancel(() => {
		resolve({canceled: true, window: undefined});
		worker.cancel();
	});

	try {
		const {stdout} = await worker;
		resolve({canceled: false, window: JSON.parse(stdout).window});
	} catch (error) {
		if (error.isCanceled || error.stdout === 'canceled') {
			resolve({canceled: true, window: undefined});
		} else {
			reject(error)
		}
	}
});
