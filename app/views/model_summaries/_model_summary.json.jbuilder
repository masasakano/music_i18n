json.extract! model_summary, :id, :modelname, :note, :created_at, :updated_at
json.url model_summary_url(model_summary, format: :json)
