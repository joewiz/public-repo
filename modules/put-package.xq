xquery version "3.1";

(:~
 : Receives uploaded packages and immediately publishes them to the package repository
 :)

import module namespace app="http://exist-db.org/xquery/app" at "app.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace scanrepo="http://exist-db.org/xquery/admin/scanrepo" at "scan.xqm";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

declare function local:log-put-package-event($filename as xs:string) as empty-sequence() {
    let $package := doc($config:raw-packages-doc)//package[@path eq $filename]
    let $today := current-date()
    let $log-doc := config:log-doc($today)
    let $event := 
        element event {
            element dateTime { current-dateTime() },
            element type { "put-package" },
            element package-name { $package/name/string() },
            element package-version { $package/version/string() }
        }
    let $update-log :=
        if (doc-available($log-doc)) then 
            update insert $event into doc($log-doc)/public-repo-log
        else
            ( 
                app:mkcol($config:logs-col, config:log-subcol($today)),
                app:store(config:log-col($today), config:log-doc-name($today), element public-repo-log { $event } )
            )
    return
        ()
};

declare function local:upload-and-publish($xar-filename as xs:string, $xar-binary as xs:base64Binary) {
    let $path := app:store($config:packages-col, $xar-filename, $xar-binary)
    let $publish := scanrepo:publish-package($xar-filename)
    return
        map { 
            "files": array {
                map { 
                    "name": $xar-filename,
                    "type": xmldb:get-mime-type($path),
                    "size": xmldb:size($config:packages-col, $xar-filename)
                }   
            }
        }
};

let $xar-filename := request:get-uploaded-file-name("files[]")
let $xar-binary := request:get-uploaded-file-data("files[]")
let $user := request:get-attribute("org.exist.public-repo.login.user")
let $required-group := config:repo-permissions()?group
return
    if (exists($user) and sm:get-user-groups($user) = $required-group) then
        try {
            local:upload-and-publish($xar-filename, $xar-binary),
            local:log-put-package-event($xar-filename)
        } catch * {
            map {
                "result": 
                    map { 
                        "name": $xar-filename,
                        "error": $err:description
                    }
            response:set-status-code(500),
            }
        }
    else
        (
            response:set-status-code(401),
            map {
                "error": "User must be a member of the " || $required-group || " group."
            }
        )
