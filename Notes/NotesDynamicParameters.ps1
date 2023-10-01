

<#
Dynamic Parameters

so the basic idea is quite simple actually

You have a parameter that has few variables.
These variables are its name, its data type and a set of attributes
These attributes can be a validated set, an alias, the parameter's position, a help message, the parameter set name, etc.

And then you create a list with these parameters, this list is called a dictionary


Here are the .NET classes for each of the above aformentioned elements:

The parameter = [System.Management.Automation.RuntimeDefinedParameter]
    to create a parameter, you give a string (the parameter's name), a datatype (the parameter's type)
    and a collection of attributes (the parameter's attributes)

The collection of attributes = System.Collections.ObjectModel.Collection[System.Attribute]

An attribute = System.Management.Automation.ParameterAttribute
    for example: [System.Management.Automation.ParameterAttribute]::new().Position
                 [System.Management.Automation.ParameterAttribute]::new().Mandatory
                 [System.Management.Automation.ParameterAttribute]::new().ValueFromPipeline
    also there are other kinds of attributes that can be added to the attributes collection like these:
                 [System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
                 [System.Management.Automation.ValidateSetAttribute]::new('Value1','Value2','etc')
    these attributes are added to the collection like so:
                 [System.Collections.ObjectModel.Collection[System.Attribute]]::new().Add($attribute)

Finally the dictionary of parameters = System.Management.Automation.RuntimeDefinedParameterDictionary
    you just add each parameter into the dictionary
    [System.Management.Automation.RuntimeDefinedParameterDictionary]:new().Add('ParameterName',$Parameter)


Here's the process from start to finish:
first you create the attribute collection
then you create an empty attribute, you set any of its properties if you wish (like the help message, the position, etc)
and then you add it to this collection
if you wish you can now create more attributes like validateset or validatenotnullorempty and add them to the collection

then you create the parameter. to do that you need to give 3 options for the paramter, its name, its datatype and the 
attribute collection we just created

now you can repeat the above process for any more parameters you want to create.

finally once you're done with all of your parameters, you create a dictionary and add them all to it
then you just output that dictionary with the return keyword

do note that by using the if statement you can essentially create only the parameters applicable to your case.
so for example if the static parameter Transport has a value of HTTP then with an if statement in the dynamic params
section you can create a new parameter called HttpPort.


#>