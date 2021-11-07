class VaccinationListsController < ApplicationController
  before_action :set_vaccination_list, only: [:set, :generate, :show, :edit, :update, :reset]

  def index
    @baby = Baby.find(params[:baby_id])
    cookies[:baby_id] = @baby.id
    @vaccination_lists = VaccinationList.where(baby_id: params[:baby_id])
  end

  def set
    vaccination_ids = VaccinationList.where("baby_id = ? AND start_date <= ? AND end_date >= ?", params[:baby_id], @vaccination_list.end_date, @vaccination_list.start_date).where(date: nil).where.not(id: params[:id]).pluck(:vaccine_id)
    @vaccines = Vaccine.where(id: vaccination_ids)
  end

  def generate
    vaccination_ids = params[:vaccination_ids] << @vaccination_list.vaccine_id.to_s
    @vaccination_lists = VaccinationList.where(baby_id: params[:baby_id], vaccine_id: vaccination_ids)
    if @vaccination_lists.update(vaccination_ids_params)
      redirect_to baby_vaccination_lists_path
    else
      render :set
    end
  end

  def show
    @vaccination_lists = VaccinationList.where(baby_id: params[:baby_id], date: @vaccination_list.date).where.not(id: params[:id])
  end

  def edit
  end

  def update
    if @vaccination_list.update(vaccination_list_params)
      redirect_to baby_vaccination_list_path
    else
      render :edit
    end
  end

  def reset
    @vaccination_lists = VaccinationList.where(baby_id: params[:baby_id], date: @vaccination_list.date)
    @vaccination_lists.update_all(date: nil)
    redirect_to baby_vaccination_lists_path
  end

  private

  def vaccination_list_params
    params.require(:vaccination_list).permit(:date).merge(baby_id: params[:baby_id], vaccine_id: @vaccination_list.vaccine_id)
  end

  def set_vaccination_list
    @vaccination_list = VaccinationList.find(params[:id])
  end

  def vaccination_ids_params
    params.permit(:date).merge(baby_id: params[:baby_id])
  end
end
