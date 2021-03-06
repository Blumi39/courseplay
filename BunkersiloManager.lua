---@class FieldManager
BunkerSiloManager = CpObject()

-- Constructor
function BunkerSiloManager:init()
	print("BunkerSiloManager: init()")

end

g_bunkerSiloManager = BunkerSiloManager()


function BunkerSiloManager:createBunkerSiloMap(vehicle, Silo, width, height)
	-- the developer could have added comments explaining what sx/wx/hx is but chose not to do so
	-- ignoring his fellow developers ...
	local sx,sz = Silo.bunkerSiloArea.sx,Silo.bunkerSiloArea.sz;
	local wx,wz = Silo.bunkerSiloArea.wx,Silo.bunkerSiloArea.wz;
	local hx,hz = Silo.bunkerSiloArea.hx,Silo.bunkerSiloArea.hz;
	local sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 1, sz);
	local bunkerWidth = courseplay:distance(sx,sz, wx, wz)
	local bunkerLength = courseplay:distance(sx,sz, hx, hz)
	local startDistance = courseplay:distanceToPoint(vehicle, sx, sy, sz)
	local endDistance = courseplay:distanceToPoint(vehicle, hx, sy, hz)
	local widthDirX,widthDirY,widthDirZ,widthDistance = courseplay:getWorldDirection(sx,sy,sz, wx,sy,wz);
	local heightDirX,heightDirY,heightDirZ,heightDistance = courseplay:getWorldDirection(sx,sy,sz, hx,sy,hz);

	local widthCount = 0
	if width then
		courseplay.debugVehicle(10, vehicle, 'Bunker width %.1f, working width %.1f (passed in)', bunkerWidth, width)
		widthCount =math.ceil(bunkerWidth/width)
	else
		courseplay.debugVehicle(10, vehicle, 'Bunker width %.1f, working width %.1f (calculated)', bunkerWidth, vehicle.cp.workWidth)
		widthCount =math.ceil(bunkerWidth/vehicle.cp.workWidth)
		width = vehicle.cp.workWidth
	end

	if vehicle.cp.mode10.leveling and courseplay:isEven(widthCount) then
		widthCount = widthCount+1
	end

	local heightCount = math.ceil(bunkerLength/ width)
	local unitWidth = bunkerWidth/widthCount
	local unitHeigth = bunkerLength/heightCount
	local heightLengthX = (Silo.bunkerSiloArea.hx-Silo.bunkerSiloArea.sx)/heightCount
	local heightLengthZ = (Silo.bunkerSiloArea.hz-Silo.bunkerSiloArea.sz)/heightCount
	local widthLengthX = (Silo.bunkerSiloArea.wx-Silo.bunkerSiloArea.sx)/widthCount
	local widthLengthZ = (Silo.bunkerSiloArea.wz-Silo.bunkerSiloArea.sz)/widthCount
	local getOffTheWall = 0.5;

	local lastValidfillType = 0
	local map = {}
	for heightIndex = 1,heightCount do
		map[heightIndex]={}
		for widthIndex = 1,widthCount do
			local newWx = sx + widthLengthX
			local newWz = sz + widthLengthZ
			local newHx = sx + heightLengthX
			local newHz = sz + heightLengthZ

			local wY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newWx, 1, newWz);
			local hY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, newHx, 1, newHz);
			local fillType = DensityMapHeightUtil.getFillTypeAtLine(newWx, wY, newWz, newHx, hY, newHz, 5)
			if lastValidfillType ~= fillType and fillType ~= 0 then
				lastValidfillType = fillType
			end
			local newFillLevel = DensityMapHeightUtil.getFillLevelAtArea(fillType, sx, sz, newWx, newWz, newHx, newHz )
			local bx = sx + (widthLengthX/2) + (heightLengthX/2)
			local bz = sz + (widthLengthZ/2) + (heightLengthZ/2)
			local offset = 0
			if vehicle.cp.mode9TargetSilo and vehicle.cp.mode9TargetSilo.type and vehicle.cp.mode9TargetSilo.type == "heap" then
				offset = unitWidth/2
			else
				if widthIndex == 1 then
					offset = getOffTheWall + (width / 2)
				elseif widthIndex == widthCount then
					offset = unitWidth- (getOffTheWall + (width / 2))
				else
					offset = unitWidth / 2
				end
			end
			local cx,cz = sx +(widthDirX*offset)+(heightLengthX/2),sz +(widthDirZ*offset)+ (heightLengthZ/2)
			if vehicle.cp.mode == courseplay.MODE_SHOVEL_FILL_AND_EMPTY and heightIndex == heightCount then
				cx,cz = sx +(widthDirX*offset)+(heightLengthX),sz +(widthDirZ*offset)+ (heightLengthZ)
			end
			local unitArea = unitWidth*unitHeigth

			map[heightIndex][widthIndex] ={
				sx = sx;	-- start?
				sz = sz;
				y = wY;
				wx = newWx; -- width?
				wz = newWz;
				hx = newHx; -- height?
				hz = newHz;
				cx = cx;     -- center
				cz = cz;
				bx = bx;
				bz = bz;
				area = unitArea;
				fillLevel = newFillLevel;
				fillType = fillType;
				bunkerLength = bunkerLength;
				bunkerWidth = bunkerWidth;
			}

			sx = map[heightIndex][widthIndex].wx
			sz = map[heightIndex][widthIndex].wz
		end
		sx = map[heightIndex][1].hx
		sz = map[heightIndex][1].hz
	end
	if lastValidfillType > 0 then
		courseplay:debug(('%s: Bunkersilo filled with %s(%i) will be devided in %d lines and %d columns'):format(nameNum(vehicle),g_fillTypeManager.indexToName[lastValidfillType], lastValidfillType, heightCount, widthCount), 10);
	else
		courseplay:debug(('%s: empty Bunkersilo will be devided in %d lines and %d columns'):format(nameNum(vehicle), heightCount, widthCount), 10);
	end
	--invert table
	if endDistance < startDistance then
		courseplay:debug(('%s: Bunkersilo will be approached from the back -> turn map'):format(nameNum(vehicle)), 10);
		local newMap = {}
		local lineCounter = #map
		for lineIndex=1,lineCounter do
			local newLineIndex = lineCounter+1-lineIndex;
			--print(string.format("put line%s into line%s",tostring(lineIndex),tostring(newLineIndex)))
			newMap[newLineIndex]={}
			local columnCount = #map[lineIndex]
			for columnIndex =1, columnCount do
				--print(string.format("  put column%s into column%s",tostring(columnIndex),tostring(columnCount+1-columnIndex)))
				newMap[newLineIndex][columnCount+1-columnIndex] = map[lineIndex][columnIndex]
			end
		end
		map = newMap
	end
	return map
end

function BunkerSiloManager:getTargetBunkerSiloByPointOnCourse(course,forcedPoint)
	local pointIndex = forcedPoint or 1 ;
	local x,_,z =  course:getWaypointPosition(pointIndex)
	local tx,tz = x,z + 0.50
	local p1x,p1z,p2x,p2z,p1y,p2y = 0,0,0,0,0,0
	if g_currentMission.bunkerSilos ~= nil then
		for _, bunker in pairs(g_currentMission.bunkerSilos) do
			local x1,z1 = bunker.bunkerSiloArea.sx,bunker.bunkerSiloArea.sz
			local x2,z2 = bunker.bunkerSiloArea.wx,bunker.bunkerSiloArea.wz
			local x3,z3 = bunker.bunkerSiloArea.hx,bunker.bunkerSiloArea.hz
			bunker.type = "silo"
			if MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z) then
				return bunker
			end
		end
	end
end

function BunkerSiloManager:getBestColumnToFill(siloMap)
	local leastFillLevel = math.huge
	local leastColumnIndex = 0
	for columnIndex=2,#siloMap[1]-1 do
		local currentFillLevel = 0
		for lineIndex=1,#siloMap do
			local fillUnit = siloMap[lineIndex][columnIndex]
			currentFillLevel = currentFillLevel + fillUnit.fillLevel
			--print(string.format("check:line %s, column %s fillLevel:%s",tostring(lineIndex),tostring(columnIndex),tostring(fillUnit.fillLevel)))
		end
		--print("column:"..tostring(columnIndex).." :"..tostring(currentFillLevel))
		if currentFillLevel<leastFillLevel then
			leastFillLevel = currentFillLevel
			leastColumnIndex = columnIndex
		end

	end
	return leastColumnIndex
end

function BunkerSiloManager:setOffsetsPerWayPoint(course,siloMap,bestColumn,ix)
	local points =	{}
	local foundFirst = 0
	for index=ix,course:getNumberOfWaypoints() do
		if self:getTargetBunkerSiloByPointOnCourse(course,index)~= nil then
			local closest,cx,cz = 0,0,0
			local leastDistance = math.huge
			for lineIndex=1,#siloMap do
				local fillUnit= siloMap[lineIndex][bestColumn]
				local x,z = fillUnit.cx,fillUnit.cz
				local distance = course:getDistanceBetweenPointAndWaypoint(x,z, index)
				if leastDistance > distance then
					leastDistance = distance
					closest = lineIndex
					cx,cz = x,z
				end
			end
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cx, 1, cz);
			course.waypoints[index].x = cx
			course.waypoints[index].z = cz
			--local offsetX,_,offsetZ = course:worldToWaypointLocal(index, cx, y, cz)
			points[index]= true
			--print(string.format("set %s new",tostring(index)))
			if foundFirst == 0 then
				foundFirst = index
			end
		elseif foundFirst ~= 0 then
			break
		end
	end

	return foundFirst
end


