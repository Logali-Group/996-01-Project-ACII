@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Incident Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'StatusCode'
@ObjectModel.usageType.serviceQuality: #A
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING
@VDM.viewType: #COMPOSITE
@Search.searchable: true
define view entity zdd_status_vh_lgl
  as select from zdt_status_lgl
{
      @ObjectModel.text.element:['StatusDescription']
  key status_code        as StatusCode,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text:true
      status_description as StatusDescription
}
