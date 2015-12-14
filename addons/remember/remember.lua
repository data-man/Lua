--Copyright (c) 2015~2016, Byrthnoth
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


-- Deals with refreshing player information and loading user settings --

_addon.name = 'PacketViewer'
_addon.author = 'Byrth'
_addon.command = 'remember'
_addon.version = '1.0.0.0'

packets = require('packets')

valid_indices = {}
novel_indices = {}
last_novel = nil

function distance(packet,player)
    return math.sqrt((packet.X-player.x)^2+(packet.Y-player.y)^2+(packet.Z-player.z)^2)
end

windower.register_event('zone change',function()
    valid_indices = {}
    novel_indices = {}
    last_novel = nil
end)

windower.register_event('incoming chunk',function(id,org,mod,inj,blk)
    local seq_id = org:byte(4)+org:byte(3)*256
    if last_novel and seq_id ~= last_novel then
        local player = windower.ffxi.get_mob_by_target('<me>')
        for i,v in pairs(novel_indices) do
            local character = windower.ffxi.get_mob_by_index(i)
            if v~= nil and (not character or character.id == 0) then
                -- We've waited a packet cycle since the first occurance of the index and real information hasn't shown up yet, so request another packet
                print('Sent out an information request for index',i)
                windower.packets.inject_outgoing(0x016,string.char(0x016,4,0,0,i%256,math.floor(i/256),0,0))
            elseif v ~= nil then
                valid_indices[i] = distance({X=character.x,Y=character.y,Z=character.z},player)
            end
            novel_indices[i] = nil -- Reset it in anticipation of a new packet
        end
        last_novel = nil
    end
    if not inj and id == 0x00D or id == 0x00E then
        local packet = packets.parse('incoming',org)
        local player = windower.ffxi.get_mob_by_target('<me>')
        if valid_indices[packet['Index']] then
            -- The monster previously existed and was still in range at its last position update
            local dist = distance(packet,player)
            if dist > 50 then
                valid_indices[packet['Index']] = nil
            else
                valid_indices[packet['Index']] = dist
            end
        elseif distance(packet,player) < 50 then
            -- The monster was not in range at its last position update or has never loaded before
            novel_indices[packet['Index']] = seq_id
            last_novel = seq_id
        end
    end
    
end)