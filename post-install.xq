xquery version "3.1";

(:~
 : This post-install script stores collection configuration for the public-repo-data collection
 : and sets permisisons on queries that need to run as repo.
 :)

import module namespace config="http://exist-db.org/xquery/apps/config" at "modules/config.xqm";

declare namespace sm="http://exist-db.org/xquery/securitymanager";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(: Helper function to recursively create a collection hierarchy :)
declare function local:mkcol-recursive($collection as xs:string, $components as xs:string*) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Create a collection hierarchy :)
declare function local:mkcol($collection as xs:string, $path as xs:string) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

(: Configuration file for the logs collection :)
declare variable $logs-xconf := 
    <collection xmlns="http://exist-db.org/collection-config/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <index>
            <range>
                <create qname="type" type="xs:string"/>
            </range>
        </index>
    </collection>;

(: Store the collection configuration :)
local:mkcol("/db/system/config", $config:logs-col),
xmldb:store("/db/system/config" || $config:logs-col, "collection.xconf", $logs-xconf),

(: execute get-package.xq as repo group, so that it can write to logs when accessed by guest users :)
sm:chmod(xs:anyURI($target || "/modules/get-package.xq"), "rwsrwxr-x")