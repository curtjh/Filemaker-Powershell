class fmq {

    [hashtable]$paramArr = @{}
    [hashtable]$infoArr = @{}
    $max = 50 #max results returned per search, change using 'maxRecords' method below
    [string]$db = ""
    [string]$layout = ""
    [string]$action = ""

    hidden [string]$URI = ""
    hidden $conn = ""
    hidden [string]$protocol = "http"
    hidden [array]$sortArr = @()
    hidden [string]$server = "yourServerIP"
    hidden [array]$acceptableActions = @("find", "delete", "findall", "edit", "view", "findquery", "findany", "new")
    hidden [string]$user = "yourUsername"
    hidden [string]$password = "YourPassword"
    hidden $cred = ""


    fmq($db,$layout) {

        $this.db = $db
        $this.layout = $layout
        $this.fmCred()

    }

    hidden [bool]isEmpty([string]$var) {

        if([string]::IsNullOrEmpty($var)) {
    
            return $true
    
        } else {
    
            return $false
    
        }
    
    }
    
    hidden fmCred() {

        #set the credentials for http authentication
        $securepassword = ConvertTo-SecureString $this.password -AsPlainText -Force
        $this.cred = New-Object System.Management.Automation.PSCredential($this.user, $securepassword)

    }

    AddParam($field,$value) {

        if($field.StartsWith('-')) { $field = $field.ToLower() }

        if($value -match "<>") {

            $value = $value.Replace("<>","")
            $fop = $field+".op"
            $this.paramArr.Add($fop,"neq")
    
        }
    
        $this.paramArr.Add($field,$value)
        
    }

    AddSort($field,$order) {

        if($order.StartsWith('a') -or $order.StartsWith('A')) {

            $order = 'ascend'

        } elseif($order.StartsWith('d') -or $order.StartsWith('d')) {

            $order = 'descend'

        } else {

            $order = 'ascend'

        }

        $this.sortArr += $field

        $theCount = $this.sortArr.count

        $this.AddParam("-sortfield.$theCount",$field)
        $this.AddParam("-sortorder.$theCount",$order)

    }

    AddSort($field) { #overloaded copy of AddSort that defaults to ascend if you don't pass an $order

        $this.sortArr += $field

        $theCount = $this.sortArr.count

        $this.AddParam("-sortfield.$theCount",$field)
        $this.AddParam("-sortorder.$theCount","ascend")

    }

    AddScript($scrName,$scrParam) {

        $this.AddParam("-script",$scrName)

        if($null -ne $scrParam) {

            $this.AddParam("script.param",$scrParam)

        }

    }

    AddScript($scrName) { #overloaded copy of AddScript that allows not passing script params

        $this.AddParam("-script",$scrName)

    }
        
    hidden addInfoItem($item,$value) {

        $this.infoArr.Add($item,$value)

    }

    hidden setURI($passedAction) {

        if($this.action -ne "dbnames" -and $this.action -ne "layoutnames" -and $this.action -ne "scriptnames") {

            $this.AddParam("-db",$this.db)
            $this.AddParam("-lay",$this.layout)
    
        } else {

            if($this.action -eq "dbnames") {

                

            } else {

                $this.AddParam("-db",$this.db)

            }

        }

        $passedAction = $passedAction.ToLower()

        $this.action = $passedAction

        $p = $this.protocol
        $s = $this.server

        if($passedAction -ne "view") {

            $this.URI = "${p}://${s}/fmi/xml/FMPXMLRESULT.xml"

        } else {

            $this.URI = "${p}://${s}/fmi/xml/FMPXMLLAYOUT.xml"

        }

    }

    maxRecords([string]$string) { # if any string is passed, show all records. (Recommended: use 'all' to make code more readable, but it could be any text)

        $this.max = $null

    }

    maxRecords() { # if method is called without args, it is assumed that it is desired to show all records, do so.

        $this.max = $null

    }

    maxRecords([int]$num) { # if a number is passed, set max records to be that number

        $this.max = $num

    }

    [System.Collections.ArrayList]sendRequest($passedAction) {

        [System.Collections.ArrayList]$res = @()

        if($this.isEmpty($this.db)) {

            $.this.addInfoItem("Error","You Must Define a Database when Instantiating this Class")
            return $res

        }

        if($this.acceptableActions.Contains($passedAction.ToLower())) {

            $this.setURI($passedAction) # $this.URI is now set

            $passedAction = "-" + $passedAction.ToLower()

            #if($null -ne $this.max) {
            if(!$this.isEmpty($this.max)) {

                $this.paramArr.Add("-max",$this.max)

            }

            $this.paramArr.Add($passedAction,"")

            try {

                $this.conn = Invoke-WebRequest -Uri $this.URI -Method POST -Body $this.paramArr -Credential $this.cred
                #$success = 1

                $xml = [xml]$this.conn

                $this.infoArr.Add("Error",$xml.fmpxmlresult.errorcode)
                $this.infoArr.Add("foundCount",$xml.fmpxmlresult.resultset.found)

                if($xml.fmpxmlresult.errorcode -eq 0) {

                    $fields = $xml.fmpxmlresult.metadata.field # the field list is nested here, assign the object to a variable
                    $rows = $xml.fmpxmlresult.resultset # the rows are nested in here, assign the object to a variable
            
                    $fArray = @() #initialize a Field array
            
                    $fields | % { #loop through the Fields and populate the field array ("%" is a shorthand alias for "Foreach-Object" in powershell)
            
                        $fArray += $_.Name # += adds a value to an array
                
                    }
            
                    #resulting $fArray is a numerically indexed array of Fields that were present on the layout
            
                    $i = 0
            
                    

                    $rows | % { # forach object in "resultset"

                        $_.ROW | % { #foreach row
                
                            $thisArr = @{} #initialize temp hashtable (assiciative array basically) to store this record's data
            
                            $_.COL | % { #foreach column
            
                                if (!$thisArr.ContainsKey($fArray[$i])) { #layout may contain field twice, only add if not there already
            
                                    $thisArr.Add($fArray[$i],$_.DATA) #fill the temp array with its associated field name ($fArray[$i]) and value ($_.DATA)
            
                                }
            
                                $i++
            
                            }
            
                            if (!$thisArr.ContainsKey("RecID")) { #this layout may already contain a field named 'RecID' if it doesn't, add it
            
                                $recID = $_.RECORDID # set this record id to a variable
                                $thisArr.Add("RecID",$recID)
            
                            }
            
                            $i = 0 #start the field list over to be used for the next record
            
                            $res.Add($thisArr) > $null #add the hashtable created for this record to the results array
            
                        }
        
                    }
            
                }
                    
            } catch {
               
                $this.infoArr.Add("Error:",$_.Exception.Message)
        
            }
            
        } else {

            $this.infoArr.Add("Error:",$passedAction + " is not an acceptable action.")

        }

        $this.addInfoItem("displayCount",$res.count)

        return $res

    }

}

