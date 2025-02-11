@Metadata.allowExtensions: true
@EndUserText.label: 'Consumption view Incident'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity zc_dt_inct_lgl
  provider contract transactional_query
  as projection on zr_dt_inct_lgl
{
  key IncUUID,
      IncidentID,
      Title,
      Description,
      Status,
      Priority,
      CreationDate,
      ChangedDate,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _History : redirected to composition child zc_dt_inct_h_lgl
}
