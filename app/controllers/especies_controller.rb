#require 'httparty'
class EspeciesController < ApplicationController

  skip_before_action :set_locale, only: [:create, :update, :edit_photos, :comentarios, :fotos_referencia,
                                         :fotos_naturalista, :fotos_bdi, :nombres_comunes_naturalista,
                                         :nombres_comunes_todos, :observaciones_naturalista, :observacion_naturalista,
                                         :ejemplares_snib, :ejemplar_snib, :cambia_id_naturalista]
  before_action :set_especie, only: [:show, :edit, :update, :destroy, :edit_photos, :update_photos, :describe,
                                     :observaciones_naturalista, :observacion_naturalista, :cat_tax_asociadas,
                                     :descripcion_catalogos, :comentarios, :fotos_bdi,
                                     :fotos_referencia, :fotos_naturalista, :nombres_comunes_naturalista,
                                     :nombres_comunes_todos, :ejemplares_snib, :ejemplar_snib, :cambia_id_naturalista,
                                     :dame_nombre_con_formato, :noticias]
  before_action :only => [:arbol, :arbol_nodo_inicial, :arbol_nodo_hojas, :arbol_identado_hojas] do
    set_especie(true)
  end

  before_action :authenticate_usuario!, :only => [:new, :create, :edit, :update, :destroy, :destruye_seleccionados, :cambia_id_naturalista]

  before_action :only => [:new, :create, :edit, :update, :destroy, :destruye_seleccionados, :cambia_id_naturalista] do
    tiene_permiso?('Administrador')  # Minimo administrador
  end

  layout false, :only => [:describe, :observaciones_naturalista, :edit_photos, :descripcion_catalogos,
                          :arbol, :arbol_nodo_inicial, :arbol_nodo_hojas, :arbol_identado_hojas, :comentarios,
                          :fotos_referencia, :fotos_bdi, :media_cornell, :fotos_naturalista, :nombres_comunes_naturalista,
                          :nombres_comunes_todos, :ejemplares_snib, :ejemplar_snib, :observacion_naturalista,
                          :cambia_id_naturalista, :dame_nombre_con_formato, :noticias]

  # Pone en cache el webservice que carga por default
  caches_action :describe, :expires_in => eval(CONFIG.cache.fichas),
                :cache_path => Proc.new { |c| "especies/#{c.params[:id]}/#{c.params[:from]}" } if Rails.env.production?

  # GET /especies
  # GET /especies.json
  def index
    redirect_to root_path
  end

  # GET /especies/1
  # GET /especies/1.json
  def show
    render 'especies/noPublicos' and return unless @especie.scat.Publico
    respond_to do |format|
      format.html do

        @datos = {}
        if adicional = @especie.adicional
          @datos[:nombre_comun_principal] =  adicional.nombre_comun_principal
          @datos[:nombres_comunes] =  adicional.nombres_comunes
        end

        @datos[:especie_o_inferior] = @especie.especie_o_inferior?

        # Para saber si es espcie y tiene un ID asociado a NaturaLista
        if proveedor = @especie.proveedor
          naturalista_id = proveedor.naturalista_id
          if naturalista_id.present?
            @datos[:naturalista_api] = "#{CONFIG.inaturalist_api}/taxa/#{naturalista_id}"
            @datos[:ficha_naturalista] = "#{CONFIG.naturalista_url}/taxa/#{naturalista_id}"
          end

          if @datos[:especie_o_inferior]
            geodatos = proveedor.geodatos

            if geodatos[:cuales].any?
              @datos[:geodatos] = geodatos
              @datos[:solo_coordenadas] = true

              # Para poner las variable con las que consulto el SNIB
              if geodatos[:cuales].include?('snib')
                if geodatos[:snib_mapa_json].present?
                  @datos[:snib_url] = geodatos[:snib_mapa_json]
                else
                  reino = @especie.root.nombre_cientifico.estandariza
                  catalogo_id = @especie.scat.catalogo_id
                  @datos[:snib_url] = "#{CONFIG.ssig_api}/snib/getSpecies/#{reino}/#{catalogo_id}?apiKey=enciclovida"
                end
              end

              # Para poner las variable con las que consulto de NaturaLista
              if geodatos[:cuales].include?('naturalista')
                if geodatos[:naturalista_mapa_json].present?
                  @datos[:naturalista_url] = geodatos[:naturalista_mapa_json]
                end
              end

              # Para poner las variable con las que consulto el Geoserver
              if geodatos[:cuales].include?('geoserver')
                if geodatos[:geoserver_url].present?
                  @datos[:geoserver_url] = geodatos[:geoserver_url]
                end
              end

            end  # End gedatos any?
          end  # End especie o inferior
        end  # End proveedor existe

        # Para las variables restantes
        @datos[:cuantos_comentarios] = @especie.comentarios.where('comentarios.estatus IN (2,3) AND ancestry IS NULL').count
        @datos[:taxon] = @especie.id
        @datos[:bdi_api] = "/especies/#{@especie.id}/fotos-bdi.json"
        @datos[:cual_ficha] = ''
        @datos[:slug_url] = "/especies/#{@especie.id}-#{@especie.nombre_cientifico.estandariza}"
      end

      format.json do
        @especie.e_geodata = []

        if @especie.especie_o_inferior?
          if proveedor = @especie.proveedor
            geodatos = proveedor.geodatos
            @especie.e_geodata = geodatos if geodatos[:cuales].any?
          end
        end

        @especie.e_nombre_comun_principal = nil
        @especie.e_foto_principal = nil
        @especie.e_nombres_comunes = nil

        if a = @especie.adicional
          @especie.e_nombre_comun_principal = a.nombre_comun_principal
          @especie.e_foto_principal = a.foto_principal
          @especie.e_nombres_comunes = a.nombres_comunes
        end

        @especie.e_categoria_taxonomica = @especie.categoria_taxonomica
        @especie.e_tipo_distribucion = @especie.tipos_distribuciones.uniq
        @especie.e_caracteristicas = @especie.catalogos
        @especie.e_bibliografia = @especie.bibliografias
        @especie.e_fotos = ["#{CONFIG.site_url}especies/#{@especie.id}/fotos-bdi.json", "#{CONFIG.site_url}especies/#{@especie.id}/fotos-naturalista.json"]  # TODO: poner las fotos de referencia, actaulmente es un metodo post

        render json: @especie.to_json(methods: [:e_geodata, :e_nombre_comun_principal, :e_foto_principal,
                                                :e_nombres_comunes, :e_categoria_taxonomica, :e_tipo_distribucion,
                                                :e_caracteristicas, :e_bibliografia, :e_fotos])
      end

      format.pdf do
        @fotos = nil

        # Fotos de naturalista
        if p = @especie.proveedor
          fotos = p.fotos_naturalista

          if fotos[:estatus] && fotos[:fotos].any?
            @fotos = []

            fotos[:fotos].each do |f|
              foto = Photo.new
              foto.large_url = f['photo']['large_url']
              foto.medium_url = f['photo']['medium_url']
              foto.native_page_url = f['photo']['native_page_url']
              foto.license = f['photo']['attribution']
              foto.square_url = f['photo']['square_url']
              foto.native_realname = f['photo']['attribution']
              @fotos << foto
            end
          end
        end

        # Fotos de BDI
        unless @fotos.present?
          fotos = @especie.fotos_bdi
          @fotos = fotos[:fotos] if fotos[:estatus] && fotos[:fotos].any?
        end

        # wicked_pdf no admite request en ajax, lo llamamos directo antes del view
        @describers = if CONFIG.taxon_describers
                        CONFIG.taxon_describers.map{|d| TaxonDescribers.get_describer(d)}.compact
                      elsif @especie.iconic_taxon_name == "Amphibia" && @especie.especie_o_inferior?
                        [TaxonDescribers::Wikipedia, TaxonDescribers::AmphibiaWeb, TaxonDescribers::Eol]
                      else
                        [TaxonDescribers::Wikipedia, TaxonDescribers::Eol]
                      end

        if params[:from].present? && CONFIG.taxon_describers.include?(params[:from].downcase)
          # Especifico una descripcion y esta dentro de los permitidos
          d = TaxonDescribers.get_describer(params[:from])
          @description = d.equal?(TaxonDescribers::EolEs) ? d.describe(@especie, :language => 'es') : d.describe(@especie)

        else  # No especifico una descripcion y mandara a llamar el que encuentre
          @describers.each do |d|
            @describer = d
            @description = begin
              d.equal?(TaxonDescribers::EolEs) ? d.describe(@especie, :language => 'es') : d.describe(@especie)
            rescue OpenURI::HTTPError, Timeout::Error => e
              nil
            end
            break unless @description.blank?
          end
        end

        ruta = Rails.root.join('public', 'pdfs').to_s
        fecha = Time.now.strftime("%Y%m%d%H%M%S")
        pdf = "#{ruta}/#{fecha}_#{rand(1000)}.pdf"
        FileUtils.mkpath(ruta, :mode => 0755) unless File.exists?(ruta)

        render :pdf => @especie.nombre_cientifico.parameterize,
               :object => @photos,
               #:save_to_file => pdf,
               #:save_only => true,
               :wkhtmltopdf => CONFIG.wkhtmltopdf_path,
               :template => 'especies/show.pdf.erb'
        #:encoding => 'UTF-8',
        #:user_style_sheet => 'http://colibri.conabio.gob.mx:4000/assets/application.css'
        #:print_media_type => false,
        #:disable_internal_links => false,
      end
    end
  end

  # GET /especies/new
  def new
    begin
      @especie = Especie.new(:parent_id => params[:parent_id])

      begin
        @parent=Especie.find(params[:parent_id])
        @cat_taxonomica=@parent.categoria_taxonomica.nombre_categoria_taxonomica
      rescue
        respond_to do |format|
          format.html { redirect_to :root, notice: 'Lo sentimos esa página no existe'.html_safe }
        end
      end

    rescue
      respond_to do |format|
        format.html { redirect_to :root, notice: "No existe un grupo o especie con el identificador: #{params[:parent_id]}." }
      end
    end
  end

  # GET /especies/1/edit
  def edit
  end

  # POST /especies
  # POST /especies.json
  def create
    argumentosRelaciones=especie_params
    argumentosRelaciones.delete(:especies_catalogos_attributes)
    argumentosRelaciones.delete(:especies_regiones_attributes)
    argumentosRelaciones.delete(:nombres_regiones_attributes)
    argumentosRelaciones.delete(:nombres_regiones_bibliografias_attributes)
    @especie = Especie.new(argumentosRelaciones)
    ascendete=Especie.find(argumentosRelaciones[:parent_id])
    @especie.ancestry_ascendente_obligatorio="#{ascendete.ancestry_ascendente_obligatorio}/#{ascendete.id}"

    respond_to do |format|
      if @especie.save && params[:commit].eql?('Crear')
        descripcion="Creó un nuevo taxón(#{@especie.id}): #{@especie.categoria_taxonomica.nombre_categoria_taxonomica} ✓ #{@especie.nombre_cientifico}"
        bitacora=Bitacora.new(:descripcion => descripcion, :usuario_id => current_usuario.id)
        bitacora.save
        guardaRelaciones(EspecieCatalogo)
        guardaRelaciones(EspecieRegion)
        format.html { redirect_to @especie, notice: "El taxón #{@especie.nombre_cientifico} fue creado exitosamente." }
        format.json { render action: 'show', status: :created, location: @especie }
      elsif @especie.save && params[:commit].eql?('Crear y seguir editando')
        descripcion="Creó un nuevo taxón: #{@especie.categoria_taxonomica.nombre_categoria_taxonomica} ✓ #{@especie.nombre_cientifico}"
        bitacora=Bitacora.new(:descripcion => descripcion, :usuario_id => current_usuario.id)
        bitacora.save
        guardaRelaciones(EspecieCatalogo)
        guardaRelaciones(EspecieRegion)
        format.html { redirect_to "/especies/#{@especie.id}/edit", notice: "El taxón #{@especie.nombre_cientifico} fue creado exitosamente." }
      else
        format.html { render action: 'new' }
        format.json { render json: @especie.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /especies/1
  # PATCH/PUT /especies/1.json
  def update
    guardaRelaciones(EspecieCatalogo)
    guardaRelaciones(EspecieRegion)
    guardaRelaciones(NombreRegion)
    guardaRelaciones(NombreRegionBibliografia)

    respond_to do |format|
      argumentosRelaciones=especie_params
      argumentosRelaciones.delete(:especies_catalogos_attributes)
      argumentosRelaciones.delete(:especies_regiones_attributes)
      argumentosRelaciones.delete(:nombres_regiones_attributes)
      argumentosRelaciones.delete(:nombres_regiones_bibliografias_attributes)

      if @especie.update(argumentosRelaciones) && params[:commit].eql?('Guardar')
        descripcion="Actualizó el taxón #{@especie.nombre_cientifico} (#{@especie.id})"
        bitacora=Bitacora.new(:descripcion => descripcion, :usuario_id => current_usuario.id)
        bitacora.save
        format.html { redirect_to @especie, notice: "El taxón #{@especie.nombre_cientifico} fue modificado exitosamente." }
        format.json { head :no_content }
      elsif @especie.update(argumentosRelaciones) && params[:commit].eql?('Guardar y seguir editando')
        descripcion="Actualizó el taxón #{@especie.nombre_cientifico} (#{@especie.id})"
        bitacora=Bitacora.new(:descripcion => descripcion, :usuario_id => current_usuario.id)
        bitacora.save
        #format.html { render action: 'edit' }
        format.html { redirect_to "/especies/#{@especie.id}/edit", notice: "El taxón #{@especie.nombre_cientifico} fue modificado exitosamente." }
        #else
        #format.html { render action: 'edit' }
        #format.json { render json: @especie.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /especies/1
  # DELETE /especies/1.json
  def destroy
    @especie.destroy
    bitacora=Bitacora.new(:descripcion => "Eliminó al taxón #{@especie.nombre_cientifico} (#{@especie.id})", :usuario_id => current_usuario.id)
    bitacora.save
    respond_to do |format|
      format.html { redirect_to especies_index_path, :notice => "El taxón #{@especie.nombre_cientifico} fue elimanado correctamente" }
      format.json { head :no_content }
    end
  end

  # REVISADO: Regresa el nombre cientifico con el formato del helper, lo uso mayormente en busquedas por 
  def dame_nombre_con_formato
  end

  # REVISADO: Despliega el arbol identado o nodo
  def arbol
    if I18n.locale.to_s == 'es-cientifico'
      @taxones = Especie.arbol_identado_inicial(@especie)
      render :partial => 'especies/arbol/arbol_identado_inicial'
    else
      render :partial => 'especies/arbol/arbol_nodo_inicial'
    end
  end

  # REVISADO: JSON que se ocupara para desplegar el arbol nodo incial en D3
  def arbol_nodo_inicial
    hash_d3 = {}
    taxones = Especie.arbol_nodo_inicial(@especie)

    taxones.reverse.each do |taxon|
      if hash_d3.empty?
        hash_d3 = taxon.arbol_nodo_hash
      else  # El taxon anterior la pone como hija del taxon actual
        parent = taxon.arbol_nodo_hash
        parent[:children] = [hash_d3]
        hash_d3 = parent
      end
    end

    render :json => hash_d3
  end

  # REVISADO: JSON que despliega los hijosen el arbol nodo, en la ficha de la especie
  def arbol_nodo_hojas
    taxones = Especie.arbol_nodo_hojas(@especie)
    render :json => taxones.map{|t| t.arbol_nodo_hash}
  end

  # REVISADO: JSON que despliega los hijos en el arbol identado, en la ficha de la especie
  def arbol_identado_hojas
    @taxones = Especie.arbol_identado_hojas(@especie)
    @hojas = true

    render :partial => 'especies/arbol/arbol_identado_hojas'
  end

  # Las fotos en el carrusel inicial, provienen de las fotos de referencia de naturalista o de bdi
  def fotos_referencia
    @fotos = []

    JSON.parse(params['fotos']).each do |foto|
      f = foto['photo'].present? ? foto['photo'] : foto
      f_obj = Photo.new
      f_obj.native_page_url = f['native_page_url']
      f_obj.medium_url = f['medium_url']
      f_obj.large_url = f['large_url']
      f_obj.square_url = f['square_url']
      f_obj.attribution_txt = f['attribution']
      @fotos << f_obj
    end

    @foto_default = @fotos.first
  end

  # Servicio de lib/bdi_service.rb
  def fotos_bdi
    @pagina = params['pagina']

    if @pagina.present?
      bdi = @especie.fotos_bdi({pagina: @pagina.to_i})
    else
      bdi = @especie.fotos_bdi
    end

    if bdi[:estatus]
      @fotos = bdi[:fotos]

      respond_to do |format|
        format.json {render json: bdi}
        format.html do

          # El conteo de las paginas
          totales = 0
          por_pagina = 25

          # Por ser la primera saco el conteo de paginas
          if @pagina.blank?
            # Saca el conteo de las fotos de bdi
            if bdi[:ultima].present?
              totales+= por_pagina*(bdi[:ultima]-1)
              fbu = @especie.fotos_bdi({pagina: bdi[:ultima]})
              totales+= fbu[:fotos].count if fbu[:estatus]
              @paginas = totales%por_pagina == 0 ? totales/por_pagina : (totales/por_pagina) + 1
            end
          end  # End pagina blank
        end  # End format html
      end  # End respond

    else  # End estatus
      render :_error and return
    end
  end

  #servicio Macaulay Library (eBird)
  def media_cornell
    type = params['type']
    page = params['page']
    taxonNC = Especie.find(params['id']).nombre_cientifico
    mc = MacaulayService.new
    @array = mc.dameMedia_nc(taxonNC, type, page)

    render :locals => {type: type, page: page}
  end

  def fotos_naturalista
    fotos = if p = @especie.proveedor
              p.fotos_naturalista
            else
              {estatus: false, msg: 'No hay resultados por nombre científico en naturalista'}
            end

    render json: fotos
  end

  def nombres_comunes_naturalista
    nombres_comunes = if p = @especie.proveedor
                        p.nombres_comunes_naturalista
                      else
                        {estatus: false, msg: 'No hay resultados por nombre científico en naturalista'}
                      end

    render json: nombres_comunes
  end

  def nombres_comunes_todos
    @nombres_comunes = @especie.dame_nombres_comunes_todos
  end

  # Viene de la pestaña de la ficha
  def describe
    @describers = if CONFIG.taxon_describers
                    CONFIG.taxon_describers.map{|d| TaxonDescribers.get_describer(d)}.compact
                  elsif @especie.iconic_taxon_name == "Amphibia" && @especie.especie_o_inferior?
                    [TaxonDescribers::Wikipedia, TaxonDescribers::AmphibiaWeb, TaxonDescribers::Eol]
                  else
                    [TaxonDescribers::Wikipedia, TaxonDescribers::Eol]
                  end

    if @describer = TaxonDescribers.get_describer(params[:from])
      @description = @describer.equal?(TaxonDescribers::EolEs) ? @describer.describe(@especie, :language => 'es') : @describer.describe(@especie)
    else
      @describers.each do |d|
        @describer = d
        @description = begin
          d.equal?(TaxonDescribers::EolEs) ? d.describe(@especie, :language => 'es') : d.describe(@especie)
        rescue OpenURI::HTTPError, Timeout::Error => e
          nil
        end
        break unless @description.blank?
      end
    end
=begin
    if @describers.include?(TaxonDescribers::Wikipedia) && @especie.wikipedia_summary.blank?
      @taxon.wikipedia_summary(:refresh_if_blank => true)
    end
=end
    @describer_url = @describer.page_url(@especie)
    respond_to do |format|
      format.html { render :partial => 'description' }
    end
  end

  # Viene de la pestaña de la ficha
  def descripcion_catalogos
  end

  # Devuelve las observaciones de naturalista en diferentes formatos
  def observaciones_naturalista
    if p = @especie.proveedor

      respond_to do |format|
        format.json do
          resp = p.observaciones_naturalista('.json')

          headers['Access-Control-Allow-Origin'] = '*'
          headers['Access-Control-Allow-Methods'] = 'GET'
          headers['Access-Control-Request-Method'] = '*'
          headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

          if resp[:estatus]
            resp[:resultados] = JSON.parse(File.read(resp[:ruta]))
            resp.delete(:ruta)
            render json: resp
          else
            resp.delete(:ruta)
            render json: resp.to_json
          end
        end

        format.kml do
          resp = p.observaciones_naturalista('.kml')

          if resp[:estatus]
            archivo = File.read(resp[:ruta])
            send_data archivo, :filename => resp[:ruta].split('/').last
          else
            resp.delete(:ruta)
            render json: resp.to_json
          end
        end

        format.kmz do
          resp = p.observaciones_naturalista('.kmz')

          if resp[:estatus]
            archivo = File.read(resp[:ruta])
            send_data archivo, :filename => resp[:ruta].split('/').last
          else
            resp.delete(:ruta)
            render json: resp.to_json
          end
        end
      end  # End respond_to
    else
      render :_error and return
    end
  end

  # Obtiene la informacion de una observacion del archivo .json, esto es para no mostrar toda la informacion cuando se construye el mapa
  def observacion_naturalista
    if p = @especie.proveedor
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'GET'
      headers['Access-Control-Request-Method'] = '*'
      headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

      resp = p.observacion_naturalista(params['observacion_id'])
      resp.delete(:ruta) if resp[:ruta].present?
      render json: resp.to_json
    else
      render json: {estatus: false, msg: 'No existe naturalista_id'}.to_json
    end
  end

  # Devuelve los ejemplares del SNIB en diferentes formatos
  def ejemplares_snib
    if p = @especie.proveedor

      respond_to do |format|
        format.json do
          resp = p.ejemplares_snib('.json')

          headers['Access-Control-Allow-Origin'] = '*'
          headers['Access-Control-Allow-Methods'] = 'GET'
          headers['Access-Control-Request-Method'] = '*'
          headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

          if resp[:estatus]
            resp[:resultados] = JSON.parse(File.read(resp[:ruta]))
            resp.delete(:ruta)
            render json: resp
          else
            resp.delete(:ruta)
            render json: resp.to_json
          end
        end

        format.kml do
          resp = p.ejemplares_snib('.kml')

          if resp[:estatus]
            archivo = File.read(resp[:ruta])
            send_data archivo, :filename => resp[:ruta].split('/').last
          else
            resp.delete(:ruta)
            render json: resp.to_json
          end
        end

        format.kmz do
          resp = p.ejemplares_snib('.kmz')

          if resp[:estatus]
            archivo = File.read(resp[:ruta])
            send_data archivo, :filename => resp[:ruta].split('/').last
          else
            resp.delete(:ruta)
            render json: resp.to_json
          end
        end
      end  # End respond_to
    else
      render :_error and return
    end
  end

  # Obtiene la informacion del ejemplar del archivo .json, esto es para no mostrar toda la informacion cuando se construye el mapa
  def ejemplar_snib
    if p = @especie.proveedor
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'GET'
      headers['Access-Control-Request-Method'] = '*'
      headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

      resp = p.ejemplar_snib(params['ejemplar_id'])
      resp.delete(:ruta) if resp[:ruta].present?
      render json: resp.to_json
    else
      render json: {estatus: false, msg: 'No existe en el SNIB'}.to_json
    end
  end

  # Muestra los comentarios relacionados a la especie, viene de la ficha de la especie
  def comentarios
    @comentarios = Comentario.datos_basicos.where(especie_id: @especie).where('comentarios.estatus IN (2,3) AND ancestry IS NULL').order('comentarios.created_at DESC')

    @comentarios.each do |c|
      c.cuantos = c.descendants.count
      c.completa_info((c.usuario_id if c.is_root?))
    end
  end

  #muestra las noticias de google Noticias ¬¬
  def noticias
    require 'rss'

    #xml = HTTParty.get("https://news.google.com/news?q=#{@especie.nombre_cientifico.limpiar}&output=rss").body
    #xml = Nokogiri::XML(open("https://news.google.com/news?q=#{@especie.nombre_cientifico.limpiar}&output=rss"))
    url = "https://news.google.com/news?q=#{@especie.nombre_cientifico.limpiar}&output=rss&hl=es-419&gl=MX&ceid=MX:es-419"
    @noticias = ''
    open(url) do |rss|
      @noticias = RSS::Parser.parse(rss)
    end
  end

  def cambia_id_naturalista
    new_id = params[:new_url].gsub(/\D/, '').to_i
    if p = @especie.proveedor
      # existe proveedor'
      p.naturalista_id = new_id
    else
      # NO existe proveedor
      p = @especie.proveedor.new({naturalista_id: new_id})
    end

    if p.changed? && p.save
      # cambio, y salvó
      @especie.borra_cache('observaciones_naturalista') if @especie.existe_cache?('observaciones_naturalista')
      redirect_to especie_path(@especie), notice: 'El cambio fue exitoso, puede que tarde un poco en lo que se actualiza el cache'
    else
      # no cambio y no salvó
      redirect_to especie_path(@especie), notice: 'No se logro el cambio, el id era el mismo, hubo un error en la url proporcionada, contactar programadores con pantallazo.'
    end
  end


  private

  def set_especie(arbol = false)
    begin  # Coincidio y es el ID de la centralizacion
      @especie = Especie.find(params[:id])
    rescue   #si no encontro el taxon, puede ser el ID viejo de millones
      if id_millon = Adicional.where(idMillon: params[:id]).first
        @especie = Especie.find(id_millon.especie_id)
      else  # Tampoco era el ID de millon
        render :_error and return
      end
    end

    # Si llego aqui quiere decir que encontro un id en la centralizacion valido
    @especie.servicios if params[:action] == 'show'

    # Por si no viene del arbol, ya que no necesito encontrar el valido
    if !arbol
      if @especie.estatus == 1  # Si es un sinonimo lo redireccciona al valido
        estatus = @especie.especies_estatus

        if estatus.length == 1  # Nos aseguramos que solo haya un valido
          begin
            @especie = Especie.find(estatus.first.especie_id2)
            redirect_to especie_path(@especie)
          rescue
            render :_error and return
          end
        elsif estatus.length > 1  # Tienes muchos validos, tampoco deberia pasar
          render :_error and return
        else  # Es sinonimo pero no tiene un valido asociado >.>!
          if params[:action] == 'resultados'  # Por si viene de resultados, ya que sin esa condicon entrariamos a un loop
            redirect_to especie_path(@especie) and return
          end
        end
      else
        if params[:action] == 'resultados'  # Mando directo al valido, por si viene de resulados
          redirect_to especie_path(@especie) and return
        end
      end
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def especie_params
    params.require(:especie).permit(:nombre, :estatus, :fuente, :nombre_autoridad, :numero_filogenetico,
                                    :cita_nomenclatural, :sis_clas_cat_dicc, :anotacion, :categoria_taxonomica_id, :parent_id,
                                    especies_catalogos_attributes: [:id, :observaciones, :catalogo_id, :_destroy],
                                    especies_regiones_attributes: [:id, :observaciones, :region_id, :tipo_distribucion_id, :_destroy],
                                    nombres_regiones_attributes: [:id, :observaciones, :region_id, :nombre_comun_id, :_destroy],
                                    nombres_regiones_bibliografias_attributes: [:id, :observaciones, :region_id, :nombre_comun_id, :bibliografia_id, :_destroy]
    )
  end

  def guardaRelaciones(tipoRelacion)
    contadorRelacion=0;
    nombreRelacion=tipoRelacion.to_s.tableize.pluralize
    relacion=Hash.new
    relacionNuevos=Hash.new

    if especie_params.has_key?("#{nombreRelacion}_attributes")
      especie_params["#{nombreRelacion}_attributes"].each do |key, value|

        relacion[contadorRelacion]=value
        contadorRelacion+=1
      end

      for rel in 0..relacion.size-1
        if relacion[rel].has_key?(:id) && relacion[rel][:_destroy].blank?
          begin
            @especie.send(nombreRelacion).where(valoresRelacion(tipoRelacion.to_s, relacion[rel], false, true)).first.update(valoresRelacion(tipoRelacion.to_s, relacion[rel]))
          rescue
          end

        elsif relacion[rel].has_key?(:id) && relacion[rel][:_destroy].present?
          begin
            criterio=valoresRelacion(tipoRelacion.to_s, relacion[rel], false, true)
            @especie.send(nombreRelacion).where(criterio).first.delete
            descripcion="Eliminó la relación #{nombreRelacion} del taxón #{@especie.nombre_cientifico} (#{@especie.id})"
            criterio.each do |atributo, valor|
              descripcion+=", caracteristica del taxón: #{Catalogo.find(valor).descripcion} (#{valor})" if atributo == :catalogo_id
              descripcion+=", región: #{Region.find(valor).nombre_region} (#{valor})" if atributo == :region_id
              descripcion+=", nombre común: #{NombreComun.find(valor).nombre_comun} (#{valor})" if atributo == :nombre_comun_id
              descripcion+=", bibliografía: #{Bibliografia.find(valor).autor.truncate(25)} (#{valor})" if atributo == :bibliografia_id
            end
            bitacora=Bitacora.new(:descripcion => descripcion, :usuario_id => current_usuario.id)
            bitacora.save
          rescue
          end
        else
          relacionNuevos ||=Hash.new
          relacionNuevos[rel]=valoresRelacion(tipoRelacion.to_s, relacion[rel], true)
        end
      end

      if relacionNuevos
        relacionNuevos.each do |key, value|
          nuevo=tipoRelacion.new(value)
          begin
            if nuevo.save
              descripcion="Agrego una nueva relación de #{nombreRelacion} al taxón: #{@especie.nombre_cientifico} (#{@especie.id})"
              value.each do |atributo, valor|
                descripcion+=", caracteristica del taxón: #{Catalogo.find(valor).descripcion} (#{valor})" if atributo == :catalogo_id
                descripcion+=", región: #{Region.find(valor).nombre_region} (#{valor})" if atributo == :region_id
                descripcion+=", tipo de distribución: #{TipoDistribucion.find(valor).descripcion} (#{valor})" if atributo == :tipo_distribucion_id
                descripcion+=", nombre común: #{NombreComun.find(valor).nombre_comun} (#{valor})" if atributo == :nombre_comun_id
                descripcion+=", bibliografía: #{Bibliografia.find(valor).autor.truncate(25)} (#{valor})" if atributo == :bibliografia_id
                descripcion+=", observaciones: #{valor}" if atributo == :observaciones
              end
              bitacora=Bitacora.new(:descripcion => descripcion, :usuario_id => current_usuario.id)
              bitacora.save
            end
          rescue
          end
        end
      end

    end
  end

  def valoresRelacion(tipoRelacion, atributos, nuevo=false, criterio=false)
    case tipoRelacion
    when 'EspecieCatalogo'
      if criterio
        condicion=atributos[:id].delete('[').delete(']').delete('"').split(',')
        {:catalogo_id => condicion[1].strip.to_i}
      else
        nuevo ? {:especie_id => @especie.id, :catalogo_id => atributos[:catalogo_id], :observaciones => atributos[:observaciones]} :
            {:catalogo_id => atributos[:catalogo_id], :observaciones => atributos[:observaciones]}
      end

    when 'EspecieRegion'
      if criterio
        condicion=atributos[:id].delete('[').delete(']').delete('"').split(',')
        {:region_id => condicion[1].strip.to_i}
      else
        nuevo ? {:especie_id => @especie.id, :region_id => atributos[:region_id], :tipo_distribucion_id => atributos[:tipo_distribucion_id],
                 :observaciones => atributos[:observaciones]} :
            {:region_id => atributos[:region_id], :tipo_distribucion_id => atributos[:tipo_distribucion_id],
             :observaciones => atributos[:observaciones]}
      end

    when 'NombreRegion'
      region ||=''
      especie_params[:especies_regiones_attributes].each do |key, value|
        if value.has_key?(:id)
          id=value[:id].delete('[').delete(']').delete('"').split(',')
          probableRegion=id[1].strip.to_i
          region=value[:region_id] if probableRegion==atributos[:region_id].to_i
        end
      end

      if criterio
        condicion=atributos[:id].delete('[').delete(']').delete('"').split(',')
        {:region_id => region, :nombre_comun_id => condicion[2].strip.to_i}
      else
        nuevo ? {:especie_id => @especie.id, :region_id => region, :nombre_comun_id => atributos[:nombre_comun_id],
                 :observaciones => atributos[:observaciones]} :
            {:nombre_comun_id => atributos[:nombre_comun_id], :observaciones => atributos[:observaciones]}
      end

    when 'NombreRegionBibliografia'
      region ||=''
      especie_params[:especies_regiones_attributes].each do |key, value|
        if value.has_key?(:id)
          id=value[:id].delete('[').delete(']').delete('"').split(',')
          probableRegion=id[1].strip.to_i
          region=value[:region_id] if probableRegion==atributos[:region_id].to_i
        end
      end

      nombre ||=''
      especie_params[:nombres_regiones_attributes].each do |key, value|
        if value.has_key?(:id)
          id=value[:id].delete('[').delete(']').delete('"').split(',')
          probableNombre=id[2].strip.to_i
          nombre=value[:nombre_comun_id] if probableNombre==atributos[:nombre_comun_id].to_i
        end
      end

      if criterio
        condicion=atributos[:id].delete('[').delete(']').delete('"').split(',')
        {:region_id => region, :nombre_comun_id => nombre, :bibliografia_id => condicion[3].strip.to_i}
      else
        nuevo ? {:especie_id => @especie.id, :region_id => region, :nombre_comun_id => nombre,
                 :bibliografia_id => atributos[:bibliografia_id], :observaciones => atributos[:observaciones]} :
            {:bibliografia_id => atributos[:bibliografia_id], :observaciones => atributos[:observaciones]}
      end
    end
  end

  def tipoDeBusqueda(tipo, columna, valor)
    case tipo.to_i
    when 1
      "caso_insensitivo('#{columna}', '#{valor}')"
    when 2
      "caso_empieza_con('#{columna}', '#{valor}')"
    when 3
      "caso_sensitivo('#{columna}', '#{valor}')"
    when 4
      "caso_termina_con('#{columna}', '#{valor}')"
    when 5
      "caso_rango_valores('#{columna}', \"#{valor}\")"
    end
  end
end
