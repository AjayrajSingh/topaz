# Contacts

> Status: Unsupported

This project will need to be refactored before it can be added to the build
again, see MS-1946 for details.

This project contains code for the [Fuchsia][fuchsia] Contacts [modules][modular].

# Structure

* **agents**: The Fuchsia agent (background services) that is the central consolidator of contacts information. It supplies searching capabilities and information about contacts.
* **modules**: Fuchsia application code using Modular APIs.
  * **contact_card**: UI module for displaying information about a single contact Entity. Can be composed into any other module that can supply it a contact Entity through link.
  * **contact_list**: UI module for listing out all contacts, searching through contacts, and displaying information about selected contacts.
  * **contacts**: Deprecated
  * **contacts_picker**: UI module that will display a list of contacts that match any prefix that is supplied to it via link.
* **services**: [FIDL][fidl] service definitions.

# Development

## Setup

This repo is already part of the default jiri manifest.

Follow the instructions for setting up a fresh Fuchsia checkout.  Once you have the `jiri` tool installed and have imported the default manifest and updated return to these instructions.

## Workflow

There are Makefile tasks setup to help simplify common development tasks. Use `make help` to see what they are.

When you have changes you are ready to see in action you can build with:

    make build

Once the system has been built you will need to run a bootserver to get it
over to a connected Acer. You can use the `fx` tool to move the build from your
host to the target device with:

    fx reboot

Once that is done (it takes a while) you can run the application with:

    make run

You can run on a connected android device with:

    make flutter-run

Optional: In another terminal you can tail the logs

    fx log

[flutter]: https://flutter.io/
[fuchsia]: https://fuchsia.googlesource.com/fuchsia/
[modular]: https://fuchsia.googlesource.com/peridot/+/master/docs/modular
[pub]: https://www.dartlang.org/tools/pub/get-started
[dart]: https://www.dartlang.org/
[fidl]: https://fuchsia.googlesource.com/garnet/+/master/public/lib/fidl
[widgets-intro]: https://flutter.io/widgets-intro/
[fuchsia-setup]: https://fuchsia.googlesource.com/fuchsia/+/HEAD/README.md
[fuchsia-env]: https://fuchsia.googlesource.com/fuchsia/+/HEAD/README.md#Setup-Build-Environment
[modules-auth]: https://fuchsia.googlesource.com/modules/#Authenticate

# Adding Contact Data Providers

On it's own, the contacts content provider agent does not request any contacts data from an external source.

To supply contact information to the contacts content provider, a separate agent should be created that will feed contact data into the contacts content provider.

1. Create a new contacta data provider agent that connects to some contacts source

2. Configure the agent to run on start up

3. Upon initialization, connect the new agent to the contacts content provider agent and call addAll, updateAll, removeAll to push in contacts data

4. If needed, add a task to the new data provider agent to poll its contact service at an interval in order to keep the contacts information up to date

## Current limitations
At the moment, the contacts content provider will not dedupe data provider agent source ids. If two data provider agents specify the same source id, it will treat them as from the same source.
