# app/controllers/patients_controller.rb
class PatientsController < ApplicationController
  # Asegura que el usuario esté autenticado para todas las acciones
  before_action :authenticate_user!
  # Encuentra el paciente para acciones específicas
  before_action :set_patient, only: %i[ show edit update destroy ]

  # GET /patients
  def index
    # Aquí usarías Pundit para definir el scope, ej:
    # @patients = policy_scope(Patient).order(created_at: :desc)
    @patients = Patient.order(created_at: :desc) # Ejemplo sin Pundit por ahora
  end

  # GET /patients/1
  def show
    # Pundit: authorize @patient
  end

  # GET /patients/new
  def new
    @patient = Patient.new
    # Pundit: authorize @patient
  end

  # GET /patients/1/edit
  def edit
    # Pundit: authorize @patient
  end

  # POST /patients
  def create
    @patient = Patient.new(patient_params)
    # Pundit: authorize @patient

    respond_to do |format|
      if @patient.save
        format.html { redirect_to patient_url(@patient), notice: "Paciente creado exitosamente." }
        # Para Turbo Streams (si el formulario está en un modal o frame diferente):
        # format.turbo_stream { render turbo_stream: turbo_stream.prepend("patients_list", partial: "patients/patient", locals: { patient: @patient }) }
      else
        format.html { render :new, status: :unprocessable_entity }
        # Para Turbo Frames (si el formulario está en un frame):
        # format.turbo_stream { render turbo_stream: turbo_stream.replace("#{helpers.dom_id(@patient)}_form", partial: "form", locals: { patient: @patient }), status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /patients/1
  def update
    # Pundit: authorize @patient
    respond_to do |format|
      if @patient.update(patient_params)
        format.html { redirect_to patient_url(@patient), notice: "Paciente actualizado exitosamente." }
        # Para Turbo Streams:
        # format.turbo_stream { render turbo_stream: turbo_stream.replace(@patient, partial: "patients/patient", locals: { patient: @patient }) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        # Para Turbo Frames:
        # format.turbo_stream { render turbo_stream: turbo_stream.replace("#{helpers.dom_id(@patient)}_form", partial: "form", locals: { patient: @patient }), status: :unprocessable_entity }
      end
    end
  end

  # DELETE /patients/1
  def destroy
    # Pundit: authorize @patient
    @patient.destroy

    respond_to do |format|
      format.html { redirect_to patients_url, notice: "Paciente eliminado exitosamente." }
      # Para Turbo Streams:
      # format.turbo_stream { render turbo_stream: turbo_stream.remove(@patient) }
    end
  end

  private
    # Usa callbacks para compartir configuración común o acciones entre acciones.
    def set_patient
      @patient = Patient.find(params[:id])
    end

    # Solo permite una lista de parámetros confiables.
    def patient_params
      params.require(:patient).permit(:name, :dob, :email, :phone, :address, :insurance_policy)
    end
end
