{
  title: 'RightSignature',

  # HTTP basic auth example.
  # Alternative example: API key
  connection: {
    fields: [
      {
        name: 'api_key',
        control_type: 'password'
      }
    ],

    authorization: {
      type: 'api_key',

      credentials: ->(connection) {
        headers('api_token': connection['api_key'])
      }
    }
  },

  object_definitions: {
    
    document: {
      fields: ->(){
        [
            { name: "guid"},
            { name: "created_at", type: :timestamp},
            { name: "completed_at", type: :timestamp},
            { name: "last_activity_at", type: :timestamp},
            { name: "expires_on", type: :timestamp },
            { name: "is_trashed"},
            { name: "size"},
            { name: "content_type"},
            { name: "original_filename"},
            { name: "signed_pdf_checksum"},
            { name: "subject"},
            { name: "message"},
            { name: "processing_state"},
            { name: "merge_state"},
            { name: "state"},
            { name: "callback_location"},
            { name: "tags"},
            { name: "recipients", type: :array, of: :object, properties: [
                { name: "name"},
                { name: "email"},
                { name: "must-sign"},
                { name: "document_role_id"},
                { name: "role_id"},
                { name: "state"},
                { name: "is_sender"},
                { name: "viewed-at"},
                { name: "completed-at"}
            ]},
            { name: "audit-trails", type: :array, of: :object, properties: [
              { name: "timestamp"},
              { name: "message"}
            ]},
          	{ name: "pages", type: :array, of: :object, properties:[
              { name: "page_number"},
              { name: "original_template_guid"},
              { name: "original_template_filename"}
            ]},
          { name: "original_url"},
          { name: "pdf_url"},
          { name: "thumbnail_url"},
          { name: "large_url"},
          { name: "signed_pdf_url"}
        ]}
    }
  },

  test: ->(connection) {
    get("https://rightsignature.com/api/documents.json")
  },

  actions: {

    get_document_details_by_id: {
      input_fields: ->(){
        [
          { name: "documentid", label:"Document ID"} 
         ]
      },
      
      execute: ->(connection, input){
        documents = get("https://rightsignature.com/api/documents/#{input['documentid']}.json")["document"]
      },
      output_fields:->(object_definitions){
        object_definitions['document']
      }
    }

  },

  triggers: {
    new_signed_document: {
      type: :paging_desc, 
      
      input_fields: ->(){
        [
        	{ name: "since", type: :timestamp}
        ]
      },
      
      poll: ->(connection, input, page){

        updated_since = page || input['since'].to_date.strftime("%Y-%m-%d") || Time.now.strftime("%Y-%m-%d")
        url = "https://rightsignature.com/api/documents.json?state=completed&updated_since=#{updated_since}"
				
        documents = get(url).params(range: updated_since)['page']['documents']

        
        	updated_since = Time.now.to_date.strftime("%Y-%m-%d")

#         updated_since = documents.last['completed_at'].to_date.strftime("%Y-%m-%d") unless documents.blank?
        
        {
          events: documents,
          next_page: updated_since
        }

      },
      
      dedup: ->(document){

      	document['guid']  
      },
      
      output_fields: ->(object_definitions){
         object_definitions['document']
      }
    }
    },

  pick_lists: {
    companies: ->(connection) {
      url = "https://#{connection['helpdesk']}.freshdesk.com/api/v2/companies.json"
      get(url).pluck('name', 'id')
    },

    contacts: ->(connection, company_id:) {
      url = "https://#{connection['helpdesk']}.freshdesk.com/api/v2/contacts.json"
      get(url, company_id: company_id).pluck('name', 'id')
    }
  },
}
