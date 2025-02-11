@EndUserText.label: 'Parameters for Change Status'
define abstract entity zdd_change_status_param_lgl
{
@EndUserText.label: 'Change Status'
@Consumption.valueHelpDefinition: [ {
    entity.name: 'zdd_status_vh_lgl',
    entity.element: 'StatusCode',
    useForValidation: true
  } ]
    status : zde_status2_lgl;    
@EndUserText.label: 'Add Observation Text'
    text : zde_text_lgl;
}
