CLASS lhc_Incident DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.

    CONSTANTS: BEGIN OF mc_status,
                 open        TYPE zde_status2_lgl VALUE 'OP',
                 in_progress TYPE zde_status2_lgl VALUE 'IP',
                 pending     TYPE zde_status2_lgl VALUE 'PE',
                 completed   TYPE zde_status2_lgl VALUE 'CO',
                 closed      TYPE zde_status2_lgl VALUE 'CL',
                 canceled    TYPE zde_status2_lgl VALUE 'CN',
               END OF mc_status.

  PRIVATE SECTION.

    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Incident~setDefaultValues.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Incident RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Incident RESULT result.

    METHODS changeStatus FOR MODIFY
      IMPORTING keys FOR ACTION Incident~ChangeStatus RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Incident RESULT result.

    METHODS setdefaulthistory FOR DETERMINE ON SAVE
      IMPORTING keys FOR incident~setdefaulthistory.
    METHODS sethistory FOR MODIFY
      IMPORTING keys FOR ACTION incident~sethistory.

    METHODS get_history_index EXPORTING ev_incuuid      TYPE sysuuid_x16
                              RETURNING VALUE(rv_index) TYPE zde_his_id_lgl.
ENDCLASS.

CLASS lhc_Incident IMPLEMENTATION.

  METHOD setDefaultValues.
** Read root entity entries
    READ ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
     ENTITY Incident
     FIELDS ( CreationDate
              Status ) WITH CORRESPONDING #( keys )
     RESULT DATA(incidents).

** This important for logic
    DELETE incidents WHERE CreationDate IS NOT INITIAL.

    CHECK incidents IS NOT INITIAL.

** Get Last index from Incidents
    SELECT FROM zdt_inct_lgl
      FIELDS MAX( incident_id ) AS max_inct_id
      WHERE incident_id IS NOT NULL
      INTO @DATA(lv_max_inct_id).

    IF lv_max_inct_id IS INITIAL.
      lv_max_inct_id = 1.
    ELSE.
      lv_max_inct_id += 1.
    ENDIF.

** Modify status in Root Entity
    MODIFY ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
      ENTITY Incident
      UPDATE
      FIELDS ( IncidentID
               CreationDate
               Status )
      WITH VALUE #(  FOR incident IN incidents ( %tky = incident-%tky
                                                 IncidentID = lv_max_inct_id
                                                 CreationDate = cl_abap_context_info=>get_system_date( )
                                                 Status       = mc_status-open )  ).
  ENDMETHOD.

  METHOD get_instance_features.
    DATA lv_history_index TYPE zde_his_id_lgl.
    READ ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
       ENTITY Incident
         FIELDS ( Status )
         WITH CORRESPONDING #( keys )
       RESULT DATA(incidents)
       FAILED failed.

** Disable changeStatus for Incidents Creation
    DATA(lv_create_action) = lines( incidents ).
    IF lv_create_action EQ 1.
      lv_history_index = get_history_index( IMPORTING ev_incuuid = incidents[ 1 ]-IncUUID ).
    ELSE.
      lv_history_index = 1.
    ENDIF.

    result = VALUE #( FOR incident IN incidents
                          ( %tky                   = incident-%tky
                            %action-ChangeStatus   = COND #( WHEN incident-Status = mc_status-completed OR
                                                                  incident-Status = mc_status-closed    OR
                                                                  incident-Status = mc_status-canceled  OR
                                                                  lv_history_index = 0
                                                             THEN if_abap_behv=>fc-o-disabled
                                                             ELSE if_abap_behv=>fc-o-enabled )

                            %assoc-_History       = COND #( WHEN incident-Status = mc_status-completed OR
                                                                 incident-Status = mc_status-closed    OR
                                                                 incident-Status = mc_status-canceled  OR
                                                                 lv_history_index = 0
                                                            THEN if_abap_behv=>fc-o-disabled
                                                            ELSE if_abap_behv=>fc-o-enabled )
                          ) ).
  ENDMETHOD.

  METHOD changeStatus.
* Declaration of necessary variables
    DATA: lt_updated_root_entity TYPE TABLE FOR UPDATE zr_dt_inct_lgl,
          lt_association_entity  TYPE TABLE FOR CREATE zr_dt_inct_lgl\_History,
          lv_status              TYPE zde_status2_lgl,
          lv_text                TYPE zde_text_lgl,
          lv_exception           TYPE string,
          lv_error               TYPE c,
          ls_incident_history    TYPE zdt_inct_h_lgl,
          lv_max_his_id          TYPE zde_his_id_lgl,
          lv_wrong_status        TYPE zde_status2_lgl.

** Iterate through the keys records to get parameters for validations
    READ ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
         ENTITY Incident
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(incidents)
         FAILED failed.

** Get parameters
    LOOP AT incidents ASSIGNING FIELD-SYMBOL(<incident>).
** Get Status
      lv_status = keys[ KEY id %tky = <incident>-%tky ]-%param-status.

**  It is not possible to change the pending (PE) to Completed (CO) or Closed (CL) status
      IF <incident>-Status EQ mc_status-pending AND lv_status EQ mc_status-closed OR
         <incident>-Status EQ mc_status-pending AND lv_status EQ mc_status-completed.
** Set authorizations
        APPEND VALUE #( %tky = <incident>-%tky ) TO failed-incident.

        lv_wrong_status = lv_status.
* Customize error messages
        APPEND VALUE #( %tky = <incident>-%tky
                        %msg = NEW zcl_incident_messages_lgl( textid = zcl_incident_messages_lgl=>status_invalid
                                                            status = lv_wrong_status
                                                            severity = if_abap_behv_message=>severity-error )
                        %state_area = 'VALIDATE_COMPONENT'
                         ) TO reported-incident.
        lv_error = abap_true.
        EXIT.
      ENDIF.

      APPEND VALUE #( %tky = <incident>-%tky
                      ChangedDate = cl_abap_context_info=>get_system_date( )
                      Status = lv_status ) TO lt_updated_root_entity.

** Get Text
      lv_text = keys[ KEY id %tky = <incident>-%tky ]-%param-text.

      lv_max_his_id = get_history_index(
                  IMPORTING
                    ev_incuuid = <incident>-IncUUID ).

      IF lv_max_his_id IS INITIAL.
        ls_incident_history-his_id = 1.
      ELSE.
        ls_incident_history-his_id = lv_max_his_id + 1.
      ENDIF.

      ls_incident_history-new_status = lv_status.
      ls_incident_history-text = lv_text.

      TRY.
          ls_incident_history-inc_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO DATA(lo_error).
          lv_exception = lo_error->get_text(  ).
      ENDTRY.

      IF ls_incident_history-his_id IS NOT INITIAL.
*
        APPEND VALUE #( %tky = <incident>-%tky
                        %target = VALUE #( (  HisUUID = ls_incident_history-inc_uuid
                                              IncUUID = <incident>-IncUUID
                                              HisID = ls_incident_history-his_id
                                              PreviousStatus = <incident>-Status
                                              NewStatus = ls_incident_history-new_status
                                              Text = ls_incident_history-text ) )
                                               ) TO lt_association_entity.
      ENDIF.
    ENDLOOP.
    UNASSIGN <incident>.

** The process is interrupted because a change of status from pending (PE) to Completed (CO) or Closed (CL) is not permitted.
    CHECK lv_error IS INITIAL.

** Modify status in Root Entity
    MODIFY ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
    ENTITY Incident
    UPDATE  FIELDS ( ChangedDate
                     Status )
    WITH lt_updated_root_entity.

    FREE incidents. " Free entries in incidents

    MODIFY ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
     ENTITY Incident
     CREATE BY \_History FIELDS ( HisUUID
                                  IncUUID
                                  HisID
                                  PreviousStatus
                                  NewStatus
                                  Text )
        AUTO FILL CID
        WITH lt_association_entity
     MAPPED mapped
     FAILED failed
     REPORTED reported.

** Read root entity entries updated
    READ ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
    ENTITY Incident
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT incidents
    FAILED failed.

** Update User Interface
    result = VALUE #( FOR incident IN incidents ( %tky = incident-%tky
                                                  %param = incident ) ).
  ENDMETHOD.

  METHOD setDefaultHistory.
** Execute internal action to update Flight Date
    MODIFY ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
    ENTITY Incident
    EXECUTE setHistory
       FROM CORRESPONDING #( keys ).
  ENDMETHOD.

  METHOD get_history_index.
** Fill history data
    SELECT FROM zdt_inct_h_lgl
      FIELDS MAX( his_id ) AS max_his_id
      WHERE inc_uuid EQ @ev_incuuid AND
            his_uuid IS NOT NULL
      INTO @rv_index.
  ENDMETHOD.

  METHOD setHistory.
** Declaration of necessary variables
    DATA: lt_updated_root_entity TYPE TABLE FOR UPDATE zr_dt_inct_lgl,
          lt_association_entity  TYPE TABLE FOR CREATE zr_dt_inct_lgl\_History,
          lv_exception           TYPE string,
          ls_incident_history    TYPE zdt_inct_h_lgl,
          lv_max_his_id          TYPE zde_his_id_lgl.

** Iterate through the keys records to get parameters for validations
    READ ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
         ENTITY Incident
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(incidents).

** Get parameters
    LOOP AT incidents ASSIGNING FIELD-SYMBOL(<incident>).
      lv_max_his_id = get_history_index( IMPORTING ev_incuuid = <incident>-IncUUID ).

      IF lv_max_his_id IS INITIAL.
        ls_incident_history-his_id = 1.
      ELSE.
        ls_incident_history-his_id = lv_max_his_id + 1.
      ENDIF.

      TRY.
          ls_incident_history-inc_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO DATA(lo_error).
          lv_exception = lo_error->get_text(  ).
      ENDTRY.

      IF ls_incident_history-his_id IS NOT INITIAL.
        APPEND VALUE #( %tky = <incident>-%tky
                        %target = VALUE #( (  HisUUID = ls_incident_history-inc_uuid
                                              IncUUID = <incident>-IncUUID
                                              HisID = ls_incident_history-his_id
                                              NewStatus = <incident>-Status
                                              Text = 'First Incident' ) )
                                               ) TO lt_association_entity.
      ENDIF.
    ENDLOOP.
    UNASSIGN <incident>.

    FREE incidents. " Free entries in incidents

    MODIFY ENTITIES OF zr_dt_inct_lgl IN LOCAL MODE
     ENTITY Incident
     CREATE BY \_History FIELDS ( HisUUID
                                  IncUUID
                                  HisID
                                  PreviousStatus
                                  NewStatus
                                  Text )
        AUTO FILL CID
        WITH lt_association_entity.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.
ENDCLASS.
