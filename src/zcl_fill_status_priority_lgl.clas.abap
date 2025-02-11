CLASS zcl_fill_status_priority_lgl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_fill_status_priority_lgl IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DELETE FROM zdt_status_lgl.
    DELETE FROM zdt_priority_lgl.

* Fill Status Data
    INSERT zdt_status_lgl FROM TABLE @( VALUE #( ( status_code = 'OP'
                                                   status_description = 'Open' )
                                                 ( status_code = 'IP'
                                                   status_description = 'In Progress' )
                                                 ( status_code = 'PE'
                                                   status_description = 'Pending' )
                                                 ( status_code = 'CO'
                                                   status_description = 'Completed' )
                                                 ( status_code = 'CL'
                                                   status_description = 'Closed' )
                                                 ( status_code = 'CN'
                                                   status_description = 'Canceled' ) ) ).
    IF sy-subrc EQ 0.
      out->write( |{ sy-dbcnt } New Status were added| ).
    ENDIF.

* Fill Priority Data
    INSERT zdt_priority_lgl FROM TABLE @( VALUE #( ( priority_code = 'H'
                                                     priority_description = 'High' )
                                                   ( priority_code = 'M'
                                                     priority_description = 'Medium' )
                                                   ( priority_code = 'L'
                                                     priority_description = 'Low' ) ) ).
    IF sy-subrc EQ 0.
      out->write( |{ sy-dbcnt } New Priorities were added| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
