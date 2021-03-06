class VaccinationListsController < ApplicationController
  before_action :set_baby
  before_action :move_to_root_path
  before_action :set_vaccination_list, only: [:set, :generate, :show, :edit, :update, :reset]
  before_action :set_vaccines, only: [:set, :generate]
  before_action :set_update_vaccines, only: [:edit, :update]
  before_action :set_show_vaccination_lists, only: [:show, :reset]

  def index
    cookies[:baby_id] = @baby.id
    @vaccination_lists = VaccinationList.includes(:vaccine).references(:vaccines).where(baby_id: params[:baby_id])
  end

  def set
  end

  def generate
    assign_attributes_vaccination_lists
    @update_vaccination_lists.each do |update_vaccination_list|
      unless update_vaccination_list.valid?
        flash.now[:alert] = "接種可能期間外のワクチンが含まれているか、接種（予定）日が未入力です！"
        render :set
        return
      end
    end
    create_next_vaccination_list
    redirect_to baby_vaccination_lists_path
  end

  def show
  end

  def edit
  end

  def update
    assign_attributes_vaccination_lists
    @update_vaccination_lists.each do |update_vaccination_list|
      unless update_vaccination_list.valid?
        flash.now[:alert] = "接種可能期間外のワクチンが含まれているか、接種（予定）日が未入力です！"
        render :edit
        return
      end
    end
    update_next_vaccination_list
    redirect_to baby_vaccination_list_path
  end

  def reset
    @reset_vaccination_lists = VaccinationList.where(baby_id: params[:baby_id], date: @vaccination_list.date)
    reset_vaccination_lists = []
    next_vaccination_lists = []
    @reset_vaccination_lists.each do |reset_vaccination_list|
      if case_reset_vaccination_list(reset_vaccination_list)
        render :show
        return
      end
      reset_vaccination_list.assign_attributes(date: nil)
      reset_vaccination_lists << reset_vaccination_list
      next_vaccination_lists << @next_vaccination_list
    end
    reset_vaccination_lists.each do |reset_vaccination_list|
      reset_vaccination_list.save(validate: false)
    end
    next_vaccination_lists.each do |next_vaccination_list|
      if next_vaccination_list != nil
        next_vaccination_list.destroy
      end
    end
    redirect_to baby_vaccination_lists_path
  end

  private

  def vaccination_list_params
    params.require(:vaccination_list).permit(:date).merge(baby_id: params[:baby_id], vaccine_id: @vaccination_list.vaccine_id)
  end

  def set_vaccination_list
    @vaccination_list = VaccinationList.find(params[:id])
  end

  def set_show_vaccination_lists
    @vaccination_lists = VaccinationList.includes(:vaccine).references(:vaccines).where(baby_id: params[:baby_id], date: @vaccination_list.date).where.not(id: params[:id])
  end

  def vaccination_ids_params
    params.permit(:date).merge(baby_id: params[:baby_id])
  end

  def set_vaccines
    vaccination_ids = VaccinationList.where("baby_id = ? AND start_date <= ? AND end_date >= ?", params[:baby_id], @vaccination_list.end_date, @vaccination_list.start_date).where(date: nil).where.not(id: params[:id]).pluck(:vaccine_id)
    @vaccines = Vaccine.where(id: vaccination_ids)
    @vaccination_lists = VaccinationList.includes(:vaccine).references(:vaccines).where("baby_id = ? AND start_date <= ? AND end_date >= ?", params[:baby_id], @vaccination_list.end_date, @vaccination_list.start_date).where(date: nil).where.not(id: params[:id])
  end

  def set_update_vaccines
    @vaccination_ids = VaccinationList.where(baby_id: params[:baby_id], date: @vaccination_list.date).where.not(id: params[:id]).pluck(:vaccine_id)
    @vaccines = Vaccine.where(id: @vaccination_ids)
    @vaccination_lists = VaccinationList.includes(:vaccine).references(:vaccines).where(baby_id: params[:baby_id], date: @vaccination_list.date).where.not(id: params[:id])
  end

  def set_baby
    @baby = Baby.find(params[:baby_id])
  end

  def move_to_root_path
    redirect_to root_path unless current_user.id == @baby.user_id
  end

  def vaccination_create(start_date, end_date, vaccine_id)
    @next_vaccination_list = VaccinationList.create(
      start_date: start_date,
      end_date: end_date,
      baby_id: @baby.id,
      vaccine_id: vaccine_id
    )
  end

  def haien_4th_compare_start_date(update_vaccination_list)
    if update_vaccination_list.date + 60.days > @baby.birthday + 12.month
      update_vaccination_list.date + 60.days
    else
      @baby.birthday + 12.month
    end
  end

  def hpv_3rd_compare_start_date(update_vaccination_list, last_vaccination_list)
    if update_vaccination_list.date + 2.month + 15.days > last_vaccination_list.date + 6.month
      update_vaccination_list.date + 2.month
    else
      last_vaccination_list.date + 6.month
    end  
  end

  def academic_year_start
    if @baby.birthday.month >= 4
      Date.new(@baby.birthday.year, 4, 1)
    else
      Date.new(@baby.birthday.year - 1, 4, 1)
    end
  end

  def academic_year_end
    if @baby.birthday.month >= 4
      Date.new(@baby.birthday.year + 1, 3, 31)
    else
      Date.new(@baby.birthday.year, 3, 31)
    end
  end

  def set_last_vaccination_list(vaccine_id)
    @last_vaccination_list = VaccinationList.find_by(baby_id: params[:baby_id], vaccine_id: vaccine_id)
  end

  def set_next_vaccination(vaccine_id)
    @next_vaccination_list = VaccinationList.find_by(baby_id: params[:baby_id], vaccine_id: vaccine_id)
  end

  def next_vaccination_check(next_vaccination_list)
    if next_vaccination_list.date != nil
      flash.now[:alert] = "先に次回の接種（予定）日を削除してください！"
      return true
    end
  end

  def assign_attributes_vaccination_lists
    if params[:vaccination_ids] == nil
      vaccine_ids = [] << @vaccination_list.vaccine_id.to_s
    else
      vaccine_ids = params[:vaccination_ids] << @vaccination_list.vaccine_id.to_s
    end
    @update_vaccination_lists = []
    vaccine_ids.each do |vaccine_id|
      unless vaccine_id == ""
        update_vaccination_list = VaccinationList.find_by(baby_id: params[:baby_id], vaccine_id: vaccine_id)
        update_vaccination_list.assign_attributes(vaccination_ids_params)
        @update_vaccination_lists << update_vaccination_list
      end
    end
  end

  def create_next_vaccination_list
    @update_vaccination_lists.each do |update_vaccination_list|
      if update_vaccination_list.save
        case update_vaccination_list.vaccine.name
        when "B型肝炎（１回目）"
          vaccination_create(update_vaccination_list.date + 4.week, @baby.birthday + 28.week, 2)
        when "B型肝炎（２回目）"
          vaccination_create(update_vaccination_list.date + 16.week, @baby.birthday + 12.month, 3)
        when "ロタウイルス（１回目）"
          vaccination_create(update_vaccination_list.date + 4.week, @baby.birthday + 24.week, 5)
        when "ロタウイルス（２回目）"
          vaccination_create(update_vaccination_list.date + 4.week, @baby.birthday + 32.week, 6)
        when "ヒブ（１回目）"
          vaccination_create(update_vaccination_list.date + 4.week, update_vaccination_list.date + 8.week, 8)
        when "ヒブ（２回目）"
          vaccination_create(update_vaccination_list.date + 4.week, update_vaccination_list.date + 8.week, 9)
        when "ヒブ（３回目）"
          set_last_vaccination_list(7)
          vaccination_create(@last_vaccination_list.date + 7.month, @baby.birthday + 5.year, 10)
        when "小児用肺炎球菌（１回目）"
          vaccination_create(update_vaccination_list.date + 4.week, @baby.birthday + 11.month, 12)
        when "小児用肺炎球菌（２回目）"
          vaccination_create(update_vaccination_list.date + 4.week, @baby.birthday + 12.month, 13)
        when "小児用肺炎球菌（３回目）"
          vaccination_create(haien_4th_compare_start_date(update_vaccination_list), @baby.birthday + 15.month, 14)
        when "四種混合（１回目）"
          vaccination_create(update_vaccination_list.date + 3.week, update_vaccination_list.date + 8.week, 16)
        when "四種混合（２回目）"
          vaccination_create(update_vaccination_list.date + 3.week, update_vaccination_list.date + 8.week, 17)
        when "四種混合（３回目）"
          vaccination_create(update_vaccination_list.date + 6.month, update_vaccination_list.date + 18.month, 18)
        when "麻しん・風しん（１回目）"
          vaccination_create(academic_year_start + 6.year, academic_year_end + 6.year, 21)
        when "水ぼうそう（１回目）"
          vaccination_create(update_vaccination_list.date + 3.month, update_vaccination_list.date + 12.month, 23)
        when "日本脳炎（１回目）"
          vaccination_create(update_vaccination_list.date + 6.days, update_vaccination_list.date + 28.days, 25)
        when "日本脳炎（２回目）"
          set_last_vaccination_list(24)
          vaccination_create(@last_vaccination_list.date + 6.month, @baby.birthday + 90.month, 26)
        when "日本脳炎（３回目）"
          vaccination_create(@baby.birthday + 9.year, @baby.birthday + 13.year, 27)
        when "HPV（１回目）"
          vaccination_create(update_vaccination_list.date + 1.month, @baby.birthday + 15.year, 29)
        when "HPV（２回目）"
          set_last_vaccination_list(28)
          vaccination_create(hpv_3rd_compare_start_date(update_vaccination_list, @last_vaccination_list), @baby.birthday + 16.year, 30)
        end
      end
    end
  end

  def update_next_vaccination_list
    @update_vaccination_lists.each do |update_vaccination_list|
      if update_vaccination_list.save
        case update_vaccination_list.vaccine.name
        when "B型肝炎（１回目）"
          vaccination_update(update_vaccination_list.date + 4.week, @baby.birthday + 28.week, 2)
        when "B型肝炎（２回目）"
          vaccination_update(update_vaccination_list.date + 16.week, @baby.birthday + 12.month, 3)
        when "ロタウイルス（１回目）"
          vaccination_update(update_vaccination_list.date + 4.week, @baby.birthday + 24.week, 5)
        when "ロタウイルス（２回目）"
          vaccination_update(update_vaccination_list.date + 4.week, @baby.birthday + 32.week, 6)
        when "ヒブ（１回目）"
          vaccination_update(update_vaccination_list.date + 4.week, update_vaccination_list.date + 8.week, 8)
        when "ヒブ（２回目）"
          vaccination_update(update_vaccination_list.date + 4.week, update_vaccination_list.date + 8.week, 9)
        when "ヒブ（３回目）"
          set_last_vaccination_list(7)
          vaccination_update(@last_vaccination_list.date + 7.month, @baby.birthday + 5.year, 10)
        when "小児用肺炎球菌（１回目）"
          vaccination_update(update_vaccination_list.date + 4.week, @baby.birthday + 11.month, 12)
        when "小児用肺炎球菌（２回目）"
          vaccination_update(update_vaccination_list.date + 4.week, @baby.birthday + 12.month, 13)
        when "小児用肺炎球菌（３回目）"
          vaccination_update(haien_4th_compare_start_date(update_vaccination_list), @baby.birthday + 15.month, 14)
        when "四種混合（１回目）"
          vaccination_update(update_vaccination_list.date + 3.week, update_vaccination_list.date + 8.week, 16)
        when "四種混合（２回目）"
          vaccination_update(update_vaccination_list.date + 3.week, update_vaccination_list.date + 8.week, 17)
        when "四種混合（３回目）"
          vaccination_update(update_vaccination_list.date + 6.month, update_vaccination_list.date + 18.month, 18)
        when "麻しん・風しん（１回目）"
          vaccination_update(academic_year_start + 6.year, academic_year_end + 6.year, 21)
        when "水ぼうそう（１回目）"
          vaccination_update(update_vaccination_list.date + 3.month, update_vaccination_list.date + 12.month, 23)
        when "日本脳炎（１回目）"
          vaccination_update(update_vaccination_list.date + 6.days, update_vaccination_list.date + 28.days, 25)
        when "日本脳炎（２回目）"
          set_last_vaccination_list(24)
          vaccination_update(@last_vaccination_list.date + 6.month, @baby.birthday + 90.month, 26)
        when "日本脳炎（３回目）"
          vaccination_update(@baby.birthday + 9.year, @baby.birthday + 13.year, 27)
        when "HPV（１回目）"
          vaccination_update(update_vaccination_list.date + 1.month, @baby.birthday + 15.year, 29)
        when "HPV（２回目）"
          set_last_vaccination_list(28)
          vaccination_update(hpv_3rd_compare_start_date(update_vaccination_list, @last_vaccination_list), @baby.birthday + 16.year, 30)
        end
      end
    end
  end

  def vaccination_update(start_date, end_date, vaccine_id)
    @next_vaccination_list = VaccinationList.find_by(baby_id: @baby.id, vaccine_id: vaccine_id)
    @next_vaccination_list.assign_attributes(
      start_date: start_date,
      end_date: end_date,
    )
    @next_vaccination_list.save(validate: false)
  end

  def flash_alert_next_exist
    flash.now[:alert] = "先に次回の接種（予定）日を削除してください！"
  end

  def case_reset_vaccination_list(reset_vaccination_list)
    case reset_vaccination_list.vaccine.name
    when "B型肝炎（１回目）"
      set_next_vaccination(2)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
      when "B型肝炎（２回目）"
      set_next_vaccination(3)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "ロタウイルス（１回目）"
      set_next_vaccination(5)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "ロタウイルス（２回目）"
      set_next_vaccination(6)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "ヒブ（１回目）"
      set_next_vaccination(8)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "ヒブ（２回目）"
      set_next_vaccination(9)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "ヒブ（３回目）"
      set_next_vaccination(10)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "小児用肺炎球菌（１回目）"
      set_next_vaccination(12)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "小児用肺炎球菌（２回目）"
      set_next_vaccination(13)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "小児用肺炎球菌（３回目）"
      set_next_vaccination(14)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "四種混合（１回目）"
      set_next_vaccination(16)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "四種混合（２回目）"
      set_next_vaccination(17)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "四種混合（３回目）"
      set_next_vaccination(18)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "麻しん・風しん（１回目）"
      set_next_vaccination(21)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "水ぼうそう（１回目）"
      set_next_vaccination(23)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "日本脳炎（１回目）"
      set_next_vaccination(25)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "日本脳炎（２回目）"
      set_next_vaccination(26)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "日本脳炎（３回目）"
      set_next_vaccination(27)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "HPV（１回目）"
      set_next_vaccination(29)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    when "HPV（２回目）"
      set_next_vaccination(30)
      if @next_vaccination_list.date != nil
        flash_alert_next_exist
        return true
      end
    end
  end
end
