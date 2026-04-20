
# Overture, with Folders.

A fork of Overture with support for `/` notation to indicate a Folder containing Overture Modules.

Example:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Overture = require(ReplicatedStorage:WaitForChild("Overture"))

--/ Test is a folder tagged with "oLibrary", so it's child-modules are only available from "Test/"
local TestA = Overture:LoadLibrary("Test/A")
local TestC = Overture:LoadLibrary("Test/C")
local OuterA = Overture:LoadLibrary("A")
local OuterB = Overture:LoadLibrary("B")

print(TestA)
print(TestC)
print(OuterA)
print(OuterB)
print(TestA ~= OuterA) -- true
```

> [!NOTE]
> You (currently) cannot have multiple Folders chained with oLibrary to build a path.
> Trying to do something like `Overture:LoadLibrary("Foo/Bar/Baz/Module")` will not work as it only supports the first folder preceding a `/`, whilst the rest is treated as the Index.

## Original README

<div align="center">
	<img src="https://raw.githubusercontent.com/devSparkle/overture-vscode/main/assets/icon-dark.png#gh-light-mode-only" alt="Overture" height="150" />
	<img src="https://raw.githubusercontent.com/devSparkle/overture-vscode/main/assets/icon.png#gh-dark-mode-only" alt="Overture" height="150" />
	<br/>
</div>

<!--moonwave-hide-before-this-line-->

>**o·ver·ture**  
>*/ˈōvərCHər,ˈōvərˌCHo͝or/*
>
>1. an orchestral piece at the beginning of an opera, suite, play, oratorio, or other extended composition.
>2. an introduction to something more substantial.

Overture is a source management module for Roblox. Overture was created to decomplexify the loading of libraries, streamline OOP classes and bridge the server-client gap!

For more information on usage, head over to the [documentation webpage](https://devsparkle.me/Overture/).


## Getting Started
Head over to the [releases tab](http://github.com/devSparkle/Overture/releases) and download the prepared `.rbxm` file. Insert this file into your game and drag the ModuleScript to `ReplicatedStorage`.

Then, require it in your code like the example below:

```lua
local Overture = require(game:GetService("ReplicatedStorage"):WaitForChild("Overture"))
```

> [!NOTE]
> You can set a `Debug` attribute on the Overture ModuleScript to get information on yielding libraries.

### Wally

Overture is also available through Wally! Include it in your project by adding the following to your `wally.toml`:
```toml
Overture = "devsparkle/overture@^2"
```

## Extension
Development with Rojo can be turbocharged with the [VSCode extension for Overture](https://marketplace.visualstudio.com/items?itemName=devSparkle.overture-vscode), which amongst other features provides typechecking support for modules required through `LoadLibrary`.
