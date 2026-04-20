--!nonstrict
--// Initialization

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

--[=[
	@class Overture
	
	The core of Overture revolves around the management of libraries.
	
	In Overture, a library is any ModuleScript which is tagged with the CollectionService `oLibrary` tag.
	Overture itself will make no effort to replicate ModuleScripts, so remember to ensure that they are
	accessible to both the server and the client; when this behavior is desired.
	
	:::info
	Remember, all library names in Overture must be unique!
	:::
]=]
local Overture = {}
local LibraryThreadCache = {}
local Libraries: {[string]: ModuleScript} = {}
local FolderedLibraries: {[string]: { [string]: ModuleScript }} = {}

--// Functions

--[=[
	@within Overture
	@ignore
]=]
local function Retrieve(InstanceName: string, InstanceClass: string, InstanceParent: Instance, ForceWait: boolean?): Instance
	if ForceWait and RunService:IsRunning() then
		return InstanceParent:WaitForChild(InstanceName)
	end
	
	local SearchInstance = InstanceParent:FindFirstChild(InstanceName)
	
	if not SearchInstance then
		SearchInstance = Instance.new(InstanceClass)
		SearchInstance.Name = InstanceName
		SearchInstance.Parent = InstanceParent
	end
	
	return SearchInstance
end

--[=[
	@within Overture
	@ignore
	
	@param Tag -- The CollectionService tag
	@param Function -- The function to call
]=]
local function BindToTag(Tag: string, Function: (Instance) -> ()): RBXScriptConnection
	for _, Value in CollectionService:GetTagged(Tag) do
		task.spawn(Function, Value)
	end
	
	return CollectionService:GetInstanceAddedSignal(Tag):Connect(Function)
end

--[=[
	@within Overture
	@ignore
	
	@param Module -- The ModuleScript to require
	@param NamedImports -- When provided, returns the named variables instead of the entire ModuleScript
	@return any?
]=]
local function RequireModule(Module: ModuleScript, NamedImports: {string}?)
	if NamedImports then
		local Exports = require(Module)
		local Imports = {}
		
		for ImportIndex, ImportName in ipairs(NamedImports) do
			Imports[ImportIndex] = Exports[ImportName]
		end
		
		return unpack(Imports)
	else
		return require(Module)
	end
end

--[=[
	Finds a ModuleScript with the CollectionService `oLibrary` tag,
	and returns the value that was returned by the given ModuleScript,
	running it if it has not been run yet.
	
	A tagged ModuleScript will only be required when LoadLibrary is called on it.
	
	The behaviour of this function differs between the server and the client.
	In the server, if no ModuleScript is found with the name provided in `Index`,
	an error is thrown. This is because **modules are expected to be tagged
	before runtime**. In the client, if no ModuleScript is found in the initial
	search, the function will yield until a ModuleScript with a matching name is
	tagged or replicated.
	
	This function makes use of coroutines and Roblox's task library to yield its
	own thread. This eliminates the processing implications of periodically
	polling every time a module is not yet present in the client, and speeds up
	the process of requiring a library once it is replicated.
	
	:::caution
	This method will yield when called on the client, but only if the library has
	not been replicated and indexed yet.
	:::
	
	:::danger
	If the library cannot be found when called on the server, this method will error.
	:::
	
	@tag Library Management
	
	@yields
	@param Index -- The name of the ModuleScript, or the name to the ModuleScript in the case of foldered libraries, in the format "Folder/Module"
	@param NamedImports -- When provided, returns the named variables instead of the entire ModuleScript
	@return any?
	
	@error The library `Index` does not exist! -- Thrown on the server, if no ModuleScript exists with the given name.
]=]
function Overture:LoadLibrary(Index: string, NamedImports: {string}?)
	local PathParts = Index:split("/") -- (Folder, Library)
	local UsesPath = #PathParts == 2
	if UsesPath and FolderedLibraries[PathParts[1]] then
		local Folder = FolderedLibraries[PathParts[1]]
		if Folder and Folder[PathParts[2]] then
			return RequireModule(Folder[PathParts[2]], NamedImports)
		else
			print(FolderedLibraries)
			assert(not RunService:IsServer(), "The foldered library \"" .. PathParts[1] .. "\" does not exist!")
			table.insert(LibraryThreadCache, {Thread = coroutine.running(), RequestedIndex = Index, RequestedAt = time()})
			return RequireModule(coroutine.yield(), NamedImports)
		end
	elseif Libraries[Index] then
		return RequireModule(Libraries[Index], NamedImports)
	else
		assert(not RunService:IsServer(), "The library \"" .. Index .. "\" does not exist!")
		
		table.insert(LibraryThreadCache, {Thread = coroutine.running(), RequestedIndex = Index, RequestedAt = time()})
		return RequireModule(coroutine.yield(), NamedImports)
	end
end

--[=[
	See [Overture:LoadLibrary] for the arguments to this method.
	This function will return nil when called on the server, regradless if the ModuleScript exists.
	
	Sugar for:
	```lua
		if RunService:IsClient() then
			Overture:LoadLibrary(...)
		end
	```	
	
	@tag Library Management
	
	@yields
	@client
	@param ... any
	@return any?
]=]
function Overture:LoadLibraryOnClient(...)
	if RunService:IsClient() then
		return self:LoadLibrary(...)
	end
end

--[=[
	See [Overture:LoadLibrary] for the arguments to this method.
	This function will return nil when called on the client, regradless if the ModuleScript exists.
	
	Sugar for:
	```lua
		if RunService:IsServer() then
			Overture:LoadLibrary(...)
		end
	```	
	
	@tag Library Management
	
	@server
	@param ... any
	@return any?
]=]
function Overture:LoadLibraryOnServer(...)
	if RunService:IsServer() then
		return self:LoadLibrary(...)
	end
end

--[=[
	Returns an instance of the specified class.
	
	If an instance of the same class and name already exists, it will be returned.
	Otherwise, when called from the client, the method will yield until one exists; if called from the server, a new one will be created.
	
	@tag Instance Retrieval
	
	@yields
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@param Parent -- An optional override parent Instance. Useful for retrieving dependencies.
]=]
function Overture:Get(InstanceClass: string, InstanceName: string, Parent: Instance?): Instance
	local SetFolder = (Parent or Retrieve(InstanceClass, "Folder", script, RunService:IsClient()))
	local Item = SetFolder:FindFirstChild(InstanceName)
	
	if Item then
		return Item
	elseif RunService:IsServer() or not RunService:IsRunning() then
		return Retrieve(InstanceName, InstanceClass, SetFolder)
	else
		return SetFolder:WaitForChild(InstanceName)
	end
end

--[=[
	Returns an instance of the specified class.
	If an instance of the same class and name already exists, it will be returned. Otherwise, a new one will be created.
	
	This function can be particularly useful to create and manage BindableEvent and BindableFunction instances for client-side communication.
	
	:::info
	Note that instances created by this function in the client will not replicate to the server, or other clients.
	:::
	
	@tag Instance Retrieval
	
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@param Parent -- An optional override parent Instance. Useful for retrieving dependencies.
]=]
function Overture:GetLocal(InstanceClass: string, InstanceName: string, Parent: Instance?): Instance
	return Retrieve(InstanceName, InstanceClass, (Parent or Retrieve("Local" .. InstanceClass, "Folder", script)))
end

--[=[
	Returns an instance of the specified class.
	If an instance of the same class and name already exists, it will be returned. Otherwise, the method will yield until one exists.
	
	@tag Instance Retrieval
	
	@yields
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@param Parent -- An optional override parent Instance. Useful for retrieving dependencies.
]=]
function Overture:WaitFor(InstanceClass: string, InstanceName: string, Parent: Instance?): Instance
	local IsClient = RunService:IsClient()
	return (Parent or Retrieve(InstanceClass, "Folder", script, IsClient)):WaitForChild(InstanceName, if IsClient then math.huge else nil)
end

task.spawn(BindToTag, "oLibrary", function(Object)
	if Object:IsA("Folder") then
		FolderedLibraries[Object.Name] = {}
		for _, Child in Object:GetChildren() do
			if Child:IsA("ModuleScript") and Child:HasTag("oLibrary") then
				FolderedLibraries[Object.Name][Child.Name] = Child
			end
		end
		return
	elseif Object.Parent and Object.Parent:IsA("Folder") and Object.Parent:HasTag("oLibrary") and Object:HasTag("oLibrary") then
		--/ Allows for clashing names of modules, as one can be in the Main Libraries, whereas another can be in a different folder or location.
		if not FolderedLibraries[Object.Parent.Name] then
			FolderedLibraries[Object.Parent.Name] = {}
		end
		local List = FolderedLibraries[Object.Parent.Name]
		if not table.find(List, Object) then
			FolderedLibraries[Object.Parent.Name][Object.Name] = Object
		end
	else
		Libraries[Object.Name] = Object
	end
	
	for _, Cached in LibraryThreadCache do
		if Object.Name == Cached.RequestedIndex then
			task.defer(Cached.Thread, Object)
			task.delay(1, function()
				table.remove(LibraryThreadCache, table.find(LibraryThreadCache, Cached))
			end)
		end
	end
end)

task.spawn(function()
	while script:GetAttribute("Debug") do
		task.wait(1)
		
		for _, Cached in LibraryThreadCache do
			if Cached.WarningEmitted then continue end
			if (time() - Cached.RequestedAt) > 5 then
				warn(string.format([[Infinite yield possible on Overture:LoadLibrary("%s").]], Cached.RequestedIndex))
				Cached.WarningEmitted = true
			end
		end
	end
end)

--// Triggers

return Overture
