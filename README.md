# Mixpanel Managed Component

## Documentation

Managed Components docs are published at **https://managedcomponents.dev** .

Find out more about Managed Components [here](https://blog.cloudflare.com/zaraz-open-source-managed-components-and-webcm/) for inspiration and motivation details.

[![Released under the Apache license.](https://img.shields.io/badge/license-apache-blue.svg)](./LICENSE)
[![PRs welcome!](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)
[![code style: prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square)](https://github.com/prettier/prettier)
[![All Contributors](https://img.shields.io/github/all-contributors/managed-components/snapchat?color=ee8449&style=flat-square)](#contributors)

## 🚀 Quickstart local dev environment

1. Make sure you're running node version >=20.
2. Install dependencies with `npm i`
3. Run unit test watcher with `npm run test:dev`

## 🔧 Setup in Cloudflare & Zaraz

### Cloudflare Worker Setup (Git Deploy)

1. Fork this repository to your own GitHub account.
2. Create a Workers KV namespace in Cloudflare:
   - Go to `Storage & Databases` -> `Workers KV` -> `Create Instance`.
   - Name it `managed-component-mixpanel-kv`.
   - Copy the namespace ID (32-char hex).
3. Create the Worker from your fork:
   - Go to `Workers & Pages` -> `Create Application`.
   - Click `Continue with GitHub`.
   - Select your forked repository.
4. Configure build/deploy in Cloudflare:
   - Build command: `npm run build`
   - Deploy command:
     `KV_ID="${KV_NAMESPACE_ID:-$KV_NAMESPACE_ID_FALLBACK}"; test -n "$KV_ID" || { echo "Missing KV namespace ID"; exit 1; }; sed "s/__KV_NAMESPACE_ID__/$KV_ID/g" wrangler.custom-mc.template.toml > wrangler.custom-mc.toml && printf "y\nn\n" | npx managed-component-to-cloudflare-worker ./dist/index.js custom-mc-managed-component-mixpanel ./wrangler.custom-mc.toml`
   - Worker name: `custom-mc-managed-component-mixpanel`.
5. Run first deploy from Cloudflare UI.
   - First deploy can fail before variables/bindings are fully configured.
6. Add KV binding in the Worker:
   - Go to `Workers & Pages` -> `custom-mc-managed-component-mixpanel` -> `Bindings` -> `Add Binding`.
   - Type: `KV namespace`
   - Variable name: `KV`
   - KV namespace: `managed-component-mixpanel-kv`
7. Add KV namespace ID as a build variable:
   - Go to `Workers & Pages` -> `custom-mc-managed-component-mixpanel` -> `Settings` -> `Build` -> `Variables and secrets`.
   - Add `KV_NAMESPACE_ID` with value set to the namespace ID copied earlier.
8. Redeploy:
   - Go to `Deployments` -> latest build -> `Retry build`.

### Mixpanel Custom Managed Component setup in Zaraz

1. Go to `Delivery & performance` -> `Web tag management` -> `Tag setup`.
2. Click `Add new tool`.
3. Select `Workers`, then choose `custom-mc-managed-component-mixpanel`.
4. Continue and grant required permissions.
5. Name and configure the tool:
   - Settings:
     - `isEU` = `true` for EU data residency projects.
     - Leave `isEU` `false` for US projects.
   - Default fields:
     - `@token` = Mixpanel project token.
6. Continue, enable tracking actions as needed, then save and publish.

### Mixpanel Event to add user profile details first time - $set_once

Use a `set_user_property` action to set user profile fields on first login/sign-up.

1. Before any `zaraz.track(...)` calls, set a unique user id via `zaraz.set(...)` so `$distinct_id` is available.
2. Send a track event with profile data, for example:

```js
zaraz.track('mp_profile_setup_completed', {
  email: 'info@example.com',
  first_name: 'Jane',
  last_name: 'Doe',
  phone: '+353 86 123 4567',
  created: '2023-10-27T14:30:00Z', // ISO 8601 UTC
  date_of_birth: '1989-01-15T00:00:00Z', // ISO 8601 UTC
  value: 125.0,
  currency: 'EUR',
})
```

3. In Zaraz, create variables for the properties you want to forward.
4. Create a new action:
   - Trigger: the track event containing profile data (for example `mp_profile_setup_completed`)
   - Action type: `Custom`
   - Event name: `set_user_property`
5. Save the action, then add fields:
   - `user-set-action` = `profile-set-once`
   - Map each field to its matching variable value:
     - `$city`
     - `$country_code`
     - `$created`
     - `$date_of_birth`
     - `$distinct_id`
     - `$email`
     - `$first_name`
     - `$last_name`
     - `$phone`
     - `$region`
     - `$timezone`

## ⚙️ Tool Settings

> Settings are used to configure the tool in a Component Manager config file

### Mixpanel Project Token `string`

The Mixpanel Project Token is the unique identifier of your Mixpanel account. [Learn more](https://help.mixpanel.com/hc/en-us/articles/115004502806-Find-Project-Token-)

### Is EU region `boolean`

Set it ON if you are enrolled in EU Data Residency. [Learn more](https://help.mixpanel.com/hc/en-us/articles/360039135652-Data-Residency-in-EU)

## 🧱 Fields Description

> Fields are properties that can/must be sent with certain events

### Track event name `string`

`event` is the event name that will be sent with a Track event. [Learn more](https://developer.mixpanel.com/reference/track-event)

### Identified ID `string`

`$identified_id` is a unique user ID that will be connected to the anonymous distinct_id of the user. It must be provided with Identify event. [Learn more](https://help.mixpanel.com/hc/en-us/articles/3600410397711#user-identification)

### Alias `string`

`alias` which Mixpanel will use to remap one id to another. Multiple aliases can point to the same identifier. It must be provided with Create alias event. [Learn more](https://help.mixpanel.com/hc/en-us/articles/360041039771#user-identification)

### Group key `string`

`$group_key` is a unique key for a group of user profiles. It must be provided with Update group properties, Delete group properties or Delete group profile events. [Learn more](https://help.mixpanel.com/hc/en-us/articles/360025333632)

### Group ID `string`

`$group_id` is the ID for a group of user profiles. It must be provided with Update group properties, Delete group properties or Delete group profile events. [Learn more](https://help.mixpanel.com/hc/en-us/articles/360025333632)

### List of properties to delete `string`

`unsetList` is a comma separated list of properties to delete. It must be provided with Delete user properties or Delete group properties events. [Learn more](https://developer.mixpanel.com/reference/group-set-property)

### Ignore alias `boolean`

`$ignore_alias` is used to ignore alias when deleting a profile. It must be provided with Delete user profile event. [Learn more](https://developer.mixpanel.com/reference/delete-profile)

### User profile action `string`

`user-set-action` specifies the action to be applied to a user profile. It must be provided with Update user properties event. [Learn more](https://developer.mixpanel.com/reference/profile-set)

### Group profile action `string`

`group-set-action` specifies the action to be applied to a group profile. It must be provided with Update group properties event. [Learn more](https://developer.mixpanel.com/reference/group-set-property)

## 📝 License

Licensed under the [Apache License](./LICENSE).

## 💜 Thanks

Thanks to everyone contributing in any manner for this repo and to everyone working on Open Source in general.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Refaerds"><img src="https://avatars.githubusercontent.com/u/57571831?v=4?s=75" width="75px;" alt="Maryna Iholnykova"/><br /><sub><b>Maryna Iholnykova</b></sub></a><br /><a href="https://github.com/managed-components/mixpanel/commits?author=Refaerds" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
