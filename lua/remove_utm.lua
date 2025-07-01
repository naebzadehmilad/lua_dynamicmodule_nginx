local args = ngx.req.get_uri_args()
local new_args = {}

for k, v in pairs(args) do
    if type(k) == "string" and not k:match("^utm_") then
        new_args[k] = v
    end
end

if next(new_args) and next(new_args) ~= next(args) then
    ngx.req.set_uri_args(new_args)
end

