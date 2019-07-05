http = require 'lapis.nginx.http'

import map, table_index from require 'lib.utils'
import from_json, to_json, trim from require 'lapis.util'
import aql, foxx_services, foxx_install, foxx_upgrade from require 'lib.arango'

--------------------------------------------------------------------------------
write_content = (filename, content)->
  file = io.open(filename, 'w+')
  io.output(file)
  io.write(content)
  io.close(file)
--------------------------------------------------------------------------------
read_zipfile = (filename)->
  file = io.open(filename, 'r')
  io.input(file)
  data = io.read('*all')
  io.close(file)
  data
--------------------------------------------------------------------------------
install_service = (sub_domain, name)->
  path = "install_service/#{sub_domain}/#{name}"
  os.execute("mkdir -p #{path}/APP/routes")
  os.execute("mkdir #{path}/APP/scripts")
  os.execute("mkdir #{path}/APP/tests")
  os.execute("mkdir #{path}/APP/libs")

  request = 'FOR api IN apis FILTER api.name == @name
      LET routes  = (FOR r IN api_routes FILTER r.api_id == api._key RETURN r)
      LET scripts = (FOR s IN api_scripts FILTER s.api_id == api._key RETURN s)
      LET tests   = (FOR t IN api_tests FILTER t.api_id == api._key RETURN t)
      LET libs    = (FOR t IN api_libs FILTER t.api_id == api._key RETURN t)
      RETURN { api, routes, scripts, tests, libs }'
  api = aql("db_#{sub_domain}", request, { 'name': name })[1]

  write_content("#{path}/APP/main.js", api.api.code)
  write_content("#{path}/APP/package.json", api.api.package)
  write_content("#{path}/APP/manifest.json", api.api.manifest)

  for k, item in pairs api.routes
    write_content("#{path}/APP/routes/#{item.name}.js", item.javascript)

  for k, item in pairs api.libs
    write_content("#{path}/APP/libs/#{item.name}.js", item.javascript)

  for k, item in pairs api.scripts
    write_content("#{path}/APP/scripts/#{item.name}.js", item.javascript)

  for k, item in pairs api.tests
    write_content("#{path}/APP/tests/#{item.name}.js", item.javascript)

  -- Install the service
  os.execute("cd install_service/#{sub_domain}/#{name}/APP && /usr/bin/npm i")
  os.execute("cd install_service/#{sub_domain} && zip -rq #{name}.zip #{name}/")
  os.execute("rm --recursive install_service/#{sub_domain}/#{name}")

  foxx_upgrade(
    "db_#{sub_domain}", name,
    read_zipfile("install_service/#{sub_domain}/#{name}.zip")
  )

--------------------------------------------------------------------------------
-- expose methods
{ :install_service }