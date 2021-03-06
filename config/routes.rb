Buscador::Application.routes.draw do

  namespace :pmc do
    resources :peces, :as => :pez do
      collection do
        get :dameNombre
      end
    end

    resources :criterios
    resources :propiedades
  end

  get 'peces' => 'pmc/peces#index'
  get 'peces/busqueda' => 'pmc/peces#index'

  resources :regiones_mapas do
    collection do
      get 'dame-tipo-region' => :dame_tipo_region
      get 'dame-ancestry' => :dame_ancestry
    end
  end

  get 'usuarios/conabio'
  get 'exoticas-invasoras' => 'paginas#exoticas_invasoras'
  get 'exoticas-invasoras-paginado' => 'paginas#exoticas_invasoras_paginado'

  resources :roles_categorias_contenido

  resources :usuarios_especie

  resources :usuarios_roles

  #match '*path' => redirect('/mantenimiento.html'), via: [:get, :post]

  get 'explora-por-ubicacion' => 'ubicaciones#ubicacion'
  get 'explora-por-region' => 'ubicaciones#por_region'
  get 'explora-por-region/especies-por-grupo' => 'ubicaciones#especies_por_grupo'
  get 'municipios-por-estado' => 'ubicaciones#municipios_por_estado'
  get 'explora-por-region/descarga-taxa' => 'ubicaciones#descarga_taxa'
  get 'explora-por-region/descarga-taxa' => 'ubicaciones#descarga_taxa'
  get 'explora-por-region/conteo-por-grupo' => 'ubicaciones#conteo_por_grupo'

  get "busquedas/basica"
  get "busquedas/avanzada"
  get "busquedas/resultados"
  get "busquedas/nombres_comunes"

  get "inicio/comentarios"
  get "inicio/index"
  get "inicio/acerca"
  get "inicio/error"

  get 'avanzada', to: "busquedas#avanzada", as: :avanzada
  get 'resultados', to: "busquedas#resultados", as: :resultados
  get 'checklist', to: "busquedas#checklist", as: :checklist
  get 'cat_tax_asociadas', to: "busquedas#cat_tax_asociadas", as: :cat_tax_asociadas

  get 'comentarios/administracion' => 'comentarios#admin', as: :admin
  post 'comentarios/:id/update_admin' => 'comentarios#update_admin'
  get 'especies/:especie_id/comentarios/:id/respuesta_externa' => 'comentarios#respuesta_externa'

  get 'comentarios/generales' => 'comentarios#extrae_comentarios_generales'
  get 'comentarios/correoId' => 'comentarios#show_correo'

  resources :adicionales do
    collection do
      post :actualiza_nom_comun
    end
  end

  resources :metadatos

  devise_for :usuarios
  resources :bitacoras

  resources :listas do
    collection do
      post :dame_listas
      post :aniade_taxones_seleccionados
    end
  end

  resources :roles

  resources :catalogos

  resources :categorias_taxonomica

  resources :usuarios do
    collection do
      post :cambia_locale
    end
  end

  resources :estatuses

  resources :especies_catalogo

  resources :especies, :except => :show, as: :especie do
    resources :comentarios  # Anida este resource para que la URL y el controlador sean mas coherentes

    collection do
      get '/:id', action: 'show', constraints: { id: /\d{1,8}[\-A-Za-z]*/ }
      post :update_photos, :as => :update_photos_for
      get ':id/arbol' => 'especies#arbol'
      get :error
      get ':id/observaciones-naturalista' => 'especies#observaciones_naturalista'
      get ':id/observacion-naturalista/:observacion_id' => 'especies#observacion_naturalista'
      get ':id/ejemplares-snib' => 'especies#ejemplares_snib'
      get ':id/ejemplar-snib/:ejemplar_id' => 'especies#ejemplar_snib'
      get ':id/arbol_nodo_inicial' => 'especies#arbol_nodo_inicial'
      get ':id/arbol_nodo_hojas' => 'especies#arbol_nodo_hojas'
      get ':id/arbol_identado_hojas' => 'especies#arbol_identado_hojas'
      post ':id/fotos-referencia' => 'especies#fotos_referencia'
      get ':id/fotos-bdi' => 'especies#fotos_bdi'
      get ':id/media-cornell' => 'especies#media_cornell'
      get ':id/fotos-naturalista' => 'especies#fotos_naturalista'
      get ':id/nombres-comunes-naturalista' => 'especies#nombres_comunes_naturalista'
      get ':id/nombres-comunes-todos' => 'especies#nombres_comunes_todos'
      post ':id/guarda-id-naturalista' => 'especies#cambia_id_naturalista'
      get ':id/dame-nombre-con-formato' => 'especies#dame_nombre_con_formato'
    end
  end

  resources :especies_bibliografia

  resources :especies_estatus

  resources :tipos_regiones

  resources :regiones

  resources :especies_regiones

  resources :tipos_distribuciones

  resources :especies_estatus_bibliografia

  resources :nombres_comunes

  resources :nombres_regiones

  resources :nombre_regiones_bibliografias

  resources :bibliografias

  match 'especies/:id/edit_photos' => 'especies#edit_photos', :as => :edit_taxon_photos, :via => :get
  match 'especies/:id/photos' => 'especies#photos', :as => :taxon_photos, :via => :get
  get 'explora_por_clasificacion' => 'especies#arbol_inicial'

  match 'adicionales/:especie_id/edita_nom_comun' => 'adicionales#edita_nom_comun', :as => :edita_nombre_comun_principal, :via => :get

  match 'flickr/photo_fields' => 'flickr#photo_fields', :via => :get
  match '/conabio/photo_fields' => 'conabio#photo_fields', :via => :get
  match '/eol/photo_fields' => 'eol#photo_fields', :via => :get
  match '/wikimedia_commons/photo_fields' => 'wikimedia_commons#photo_fields', :via => :get
  #match 'photos/local_photo_fields' => 'photos#local_photo_fields', :as => :local_photo_fields
  match '/photos/:id/repair' => 'photos#repair', :as => :photo_repair, :via => :put
  match 'flickr/photos.:format' => 'flickr#photos', :via => :get
  match '/especies/:id/describe' => 'especies#describe', :as => :descripcion, :via => :get
  get '/especies/:id/descripcion_catalogos' => 'especies#descripcion_catalogos'
  get '/especies/:id/comentario' => 'especies#comentarios'
  get '/especies/:id/noticias' => 'especies#noticias'

  resources :photos, :only => [:show, :update, :destroy] do
    member do
      put :rotate
    end
  end


  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'inicio#index'

  # Example of regular route:
  post 'especies/new/:parent_id' => 'especies#new', :via => :post, :as => 'new'
  mount Soulmate::Server, :at => '/sm'

  # Webservice para la validacion de nuevos o actualizados records (pendiente)
  #wash_out :webservice

  # End-points para la validacion de nuevos o actualizados records (actual)
  post 'validaciones/update' => 'validaciones#update'
  post 'validaciones/insert' => 'validaciones#insert'
  post 'validaciones/delete' => 'validaciones#delete'

  # Para las validaciones de taxones la simple y la avanzada
  get 'validaciones' => 'validaciones#index'
  #get 'validaciones/simple' => 'validaciones#simple', as: 'validacion_simple'
  #get 'validaciones/avanzada' => 'validaciones#avanzada', as: 'validacion_avanzada'
  post 'validaciones/simple' => 'validaciones#simple', as: 'validacion_simple'
  post 'validaciones/avanzada' => 'validaciones#avanzada', as: 'validacion_avanzada'

  get 'bdi_nombre_cientifico' => 'webservice#bdi_nombre_cientifico'

  get 'geojson-a-topojson' => 'webservice#geojson_a_topojson'
  post 'geojson-a-topojson' => 'webservice#geojson_a_topojson'

end
