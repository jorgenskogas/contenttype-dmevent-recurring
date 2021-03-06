﻿<!--- @@Copyright: Copyright (c) 2014 Amerika Design & Utvikling AS. All rights reserved. --->
<!--- @@License:
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
--->

<!--- @@displayname: dmEvent.cfc --->
<!--- @@description: There is no description for this template. Please add or remove this message. --->
<!--- @@author: Jørgen M. Skogås (jorgen@amerika.no) on 2014-01-23 --->

<cfcomponent extends="farcry.plugins.farcrycms.packages.types.dmevent">

	<cfproperty ftSeq="100" ftWizardStep="Repetisjon" ftFieldset="Repetisjonvalg"
				name="recurringSetting" type="string" required="true" default=""
				ftLabel="Repeter?" ftType="list" ftList=":Aldri,d:Hver dag,ww:Hver uke,m:Hver måned,yyyy:Hvert år"
				ftHint="Det er ikke mulig å endre på repetisjonsvalg når repeterende aktiviteter er opprettet. Aktiviteter som repeterer hvert år og som har dato 29. februar vil bli flyttet til den 28 februar for de år som ikke har 29. februar." />
				
	<cfproperty ftseq="101" ftWizardStep="Repetisjon" ftFieldset="Repetisjonvalg"
				name="recurringEndDate" type="date" required="no" default=""
				ftlabel="Stopp repetisjon" ftType="datetime"
				ftDefaultType="Evaluate" ftDefault="DateAdd('d', 365, now())" ftDateFormatMask="dd mmm yyyy" ftTimeFormatMask="hh:mm tt" ftShowTime="false" ftToggleOffDateTime="true"
				ftHint="Siste mulige dag aktiviteten kan repetere på. Systemet har en øvre grense på 100 repetisjoner pr aktivitet, uavhengig om det er satt en sluttdato eller ikke." />
	
	<!--- Hidden --->
	<cfproperty name="masterID" type="UUID" required="false" default="" />
	
	<!--- Methods --->
	<cffunction name="afterSave" access="public" output="true" returntype="struct">
		<cfargument name="stProperties" type="struct" required="true" />
		
		<!--- Only run on events that are set to recurring and when status change from draft to approved --->
		<cfif (trim(arguments.stProperties.recurringSetting) IS NOT "") AND
			  (arguments.previousStatus IS "draft" AND arguments.stProperties.status IS 'approved')>
			  
			<cfset bHasChilds = application.fapi.getContentObjects(typename="dmEvent", masterID_eq=arguments.stProperties.objectID).recordCount GT 0 />
			
			<!--- MASTER
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////// --->
			<cfif trim(arguments.stProperties.masterID) EQ "">
				<!--- Create childs --->
				<cfif bHasChilds IS false>
					<cfset stCreateChilds = createChilds(argumentCollection=arguments) />
				<cfelse>
					<cfset stUpdateAll = updateAll(argumentCollection=arguments, bIncludeMaster=false) />
				</cfif>
			<cfelseif trim(arguments.stProperties.masterID) NEQ "">
				<!--- CHILD
				//////////////////////////////////////////////////////////////////////////////////////////////////////////////////// --->
				<cfset stUpdateAll = updateAll(argumentCollection=arguments, bIncludeMaster=true) />
			</cfif>
		</cfif>
		
		
		
		<cfset stSuper = super.afterSave(stProperties=arguments.stProperties) />
		
		<cfreturn stSuper />
	</cffunction>
	
	<cffunction name="createChilds" access="public" output="true" returntype="any">
		<cfargument name="stProperties" type="struct" required="true" />
		
		<cfset var loopDate = arguments.stProperties.startDate />
		<cfset var counter = 0 />
		<cfset var stMasterCopyObj = duplicate(arguments.stProperties) />
		<cfset stMasterCopyObj.masterID = arguments.stProperties.objectID />
		
		<!--- 
		yyyy: Year (et år)
		m: Month (en måned)
		d: Day (en dag)
		ww: Week (en uke)
		--->
		<cfloop from="1" to="100" index="i">
			<!--- Add more time: 5 seconds --->
			<cfsetting requesttimeout="60" />
			
			<!--- Calculate loop counter and dates--->
			<cfset counter = counter + 1 />
			<cfset stDates = structNew() />
			<cfset stDates.loopStartDate = "" />
			<cfset stDates.loopEndDate = "" />
			<cfif trim(arguments.stProperties.startDate) NEQ "">
				<cfset stDates.loopStartDate = dateAdd(arguments.stProperties.recurringSetting, counter, arguments.stProperties.startDate) />
			</cfif>
			<cfif trim(arguments.stProperties.endDate) NEQ "">
				<cfset stDates.loopEndDate = dateAdd(arguments.stProperties.recurringSetting, counter, arguments.stProperties.endDate) />
			</cfif>
			
			<!--- Validate date, break loop if date is greater than recurringEndDate --->
			<cfif stDates.loopStartDate NEQ "" AND isDate(arguments.stProperties.recurringEndDate) AND dateCompare(stDates.loopStartDate, arguments.stProperties.recurringEndDate, 'd') GTE 1>
				<cfbreak />
			</cfif>
			<cfset stMasterCopyObj.startDate = stDates.loopStartDate />
			<cfset stMasterCopyObj.endDate = stDates.loopEndDate />
			<cfset stMasterCopyObj.objectID = createUUID() />
			<cfset stSave = application.fapi.setData(stProperties=stMasterCopyObj, bAfterSave=false) />
		</cfloop>
		
	</cffunction>
	
	<cffunction name="updateAll" access="public" output="true" returntype="any">
		<cfargument name="stProperties" type="struct" required="true" />
		<cfargument name="bIncludeMaster" type="boolean" required="true" default="false" />
		
		<cfset var qObjUpdate = queryNew("blah") />
		<cfset var masterObjID = "" />
		
		<cfif trim(arguments.stProperties.masterID) EQ "">
			<cfset masterObjID = arguments.stProperties.objectID />
		<cfelse>
			<cfset masterObjID = arguments.stProperties.masterID />
		</cfif>

		<cfquery name="qObjUpdate" datasource="#application.dsn#">
			UPDATE dmEvent
			SET label = '#arguments.stProperties.label#', title = '#arguments.stProperties.title#', catEvent = '#arguments.stProperties.catEvent#', location = '#arguments.stProperties.location#', teaser = '#arguments.stProperties.teaser#', body = '#arguments.stProperties.body#'
			WHERE masterID = '#masterObjID#'
			<cfif arguments.bIncludeMaster>
				OR objectID = '#masterObjID#'
			</cfif>
		</cfquery>
		
		<cfset application.fapi.flushCache('dmEvent') />
		
	</cffunction>
	
</cfcomponent>