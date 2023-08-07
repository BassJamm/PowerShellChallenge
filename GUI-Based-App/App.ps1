Add-Type -AssemblyName System.windows.forms

# Create Objects.
$formobject = [System.windows.forms.form]
$labelobject = [System.windows.forms.label]
$ComboBoxObject = [System.Windows.Forms.ComboBox]

#Gloabl Values.
$DefaultFont = 'Verderna,12'

# Form\Window Title.
$AppForm = New-Object $formobject
$AppForm.ClientSize = '500,300'
$AppForm.Text = 'Service Inspector'
$AppForm.Font = $DefaultFont
$AppForm.BackColor = "#ffffff"

# Build the form.
$lblService = New-Object $labelobject
$lblService.Text = 'Services: '
$lblService.AutoSize = $true
$lblService.Location = New-Object System.Drawing.Point(20, 20)

$ddlService = New-Object  $ComboBoxObject
$ddlService.Width = '300'
$ddlService.Text = 'Pick a service'
$ddlService.Location = New-Object System.Drawing.Point(140, 20)

$lblForName = New-Object $labelobject
$lblForName.Text = 'Service Friendly Name: '
$lblForName.AutoSize = $true
$lblForName.Location = New-Object System.Drawing.Point(20, 80)

$lblSvcName = New-Object $labelobject
$lblSvcName.Text = ''
$lblSvcName.AutoSize = $true
$lblSvcName.Location = New-Object System.Drawing.Point(220, 80)

$lblForStatus = New-Object $labelobject
$lblForStatus.Text = 'Status: '
$lblForStatus.AutoSize = $true
$lblForStatus.Location = New-Object System.Drawing.Point(20, 120)

$lblStatus = New-Object $labelobject
$lblStatus.Text = ''
$lblStatus.AutoSize = $true
$lblStatus.Location = New-Object System.Drawing.Point(220, 120)

# Adds the above objects to the AppForm Window.
$AppForm.Controls.AddRange(@($lblService,$ddlService,$lblForName,$lblSvcName,$lblForStatus,$lblStatus))

# Logic\fuctions.

# Gets the services and passes them into the drop down form.
Get-Service  | ForEach-Object { $ddlService.items.add( $_.Name) }


function GetServiceDetails{
    # Gets the selected item from the dropdown menu ddlService.
    $ServiceName = $ddlService.SelectedItem
    $details = Get-Service -Name $ServiceName | Select-object DisplayName,Status
    $lblSvcName.Text = $details.DisplayName
    $lblStatus.Text = $details.Status

    if($lblStatus.Text -eq 'Running') {
        # Turn the text Green.
        $lblStatus.ForeColor = 'green'
    } else {
        # Turn text Red.
        $lblStatus.ForeColor = 'red'
    }
}

# When the dropdown menu is changed, it will run the function, GetServiceDetails
$ddlService.Add_SelectedIndexChanged({GetServiceDetails})

# Create window, put all forms, buttons etc before this line.
$AppForm.ShowDialog()

# Cleans up form.
$AppForm.Dispose()